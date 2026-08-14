import { Injectable, Logger } from '@nestjs/common';
import { spawn, SpawnOptions } from 'child_process';
import { promises as fs } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { randomUUID } from 'crypto';

export interface FrameExtractionResult {
  frames: Array<{
    index: number;
    label: string;
    type: 'keyframe' | 'sample';
    path: string;
    size: number;
  }>;
  frameCount: number;
  duration: number;
}

export interface FrameExtractionOptions {
  videoPath: string;
  outputDir?: string;
  maxFrames?: number;
  keyframeInterval?: number;
  thumbnailSize?: string; // e.g., '320x240'
}

@Injectable()
export class FrameExtractorService {
  private readonly logger = new Logger(FrameExtractorService.name);

  /**
   * Extract frames from a video file using FFmpeg
   */
  async extractFrames(options: FrameExtractionOptions): Promise<FrameExtractionResult> {
    const {
      videoPath,
      outputDir = join(tmpdir(), `frame-extract-${randomUUID()}`),
      maxFrames = 50,
      keyframeInterval = 1, // Extract every keyframe
      thumbnailSize = '320x240',
    } = options;

    // Verify video file exists
    try {
      await fs.access(videoPath);
    } catch {
      throw new Error(`Video file not found: ${videoPath}`);
    }

    // Create output directory
    await fs.mkdir(outputDir, { recursive: true });

    // Get video duration first
    const duration = await this.getVideoDuration(videoPath);
    
    // Calculate frame extraction interval
    // Extract frames at regular intervals, but prioritize keyframes
    const frameInterval = Math.max(duration / maxFrames, 1);
    
    // Extract frames using FFmpeg
    const framePaths = await this.extractFramesWithFFmpeg({
      videoPath,
      outputDir,
      frameInterval,
      keyframeInterval,
      thumbnailSize,
      maxFrames,
    });

    // Read frame files and get their sizes
    const frames = [];
    for (let i = 0; i < framePaths.length; i++) {
      const framePath = framePaths[i];
      const stats = await fs.stat(framePath);
      frames.push({
        index: i,
        label: `Frame ${i + 1}`,
        type: i % 10 === 0 ? 'keyframe' : 'sample',
        path: framePath,
        size: stats.size,
      });
    }

    // Clean up temporary directory if it's in tmp
    if (outputDir.startsWith(tmpdir())) {
      // Optionally clean up - comment out if you want to keep frames
      // await this.cleanupDirectory(outputDir);
    }

    return {
      frames,
      frameCount: frames.length,
      duration,
    };
  }

  /**
   * Get video duration using FFprobe
   */
  private async getVideoDuration(videoPath: string): Promise<number> {
    return new Promise((resolve, reject) => {
      const ffprobe = spawn('ffprobe', [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        videoPath,
      ]);

      let output = '';
      ffprobe.stdout.on('data', (data) => {
        output += data.toString();
      });

      ffprobe.stderr.on('data', (data) => {
        // FFprobe outputs to stderr
      });

      ffprobe.on('close', (code) => {
        if (code === 0) {
          const duration = parseFloat(output.trim());
          resolve(isNaN(duration) ? 0 : duration);
        } else {
          reject(new Error(`ffprobe exited with code ${code}`));
        }
      });

      ffprobe.on('error', (err) => {
        reject(new Error(`Failed to spawn ffprobe: ${err.message}`));
      });
    });
  }

  /**
   * Extract frames using FFmpeg
   */
  private async extractFramesWithFFmpeg(options: {
    videoPath: string;
    outputDir: string;
    frameInterval: number;
    keyframeInterval: number;
    thumbnailSize: string;
    maxFrames: number;
  }): Promise<string[]> {
    const { videoPath, outputDir, frameInterval, keyframeInterval, thumbnailSize, maxFrames } = options;

    return new Promise((resolve, reject) => {
      // FFmpeg command to extract frames
      // -ss: seek to position (we'll extract at intervals)
      // -vf: video filter for frame selection and scaling
      // -vsync: sync method
      // -q:v: quality (2 is high quality)
      
      const ffmpegArgs = [
        '-i', options.videoPath,
        '-vf', `select='eq(pict_type\,I)',scale=${options.thumbnailSize}`, // Extract keyframes only, scale
        '-vsync', 'vfr', // Variable frame rate
        '-q:v', '2', // High quality
        '-frame_pts', '1', // Use presentation timestamps
        '-start_number', '0',
        '-y', // Overwrite output files
        join(outputDir, 'frame_%04d.jpg'),
      ];

      this.logger.debug(`Running FFmpeg: ffmpeg ${ffmpegArgs.join(' ')}`);

      const ffmpeg = spawn('ffmpeg', ffmpegArgs);

      let stderr = '';
      ffmpeg.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      let frameCount = 0;
      ffmpeg.stdout.on('data', (data) => {
        // FFmpeg outputs frame info to stdout sometimes
      });

      ffmpeg.on('close', async (code) => {
        if (code === 0) {
          // List extracted frames
          try {
            const files = await fs.readdir(outputDir);
            const frameFiles = files
              .filter((f) => f.endsWith('.jpg'))
              .sort((a, b) => {
                const numA = parseInt(a.match(/\d+/)?.[0] || '0', 10);
                const numB = parseInt(b.match(/\d+/)?.[0] || '0', 10);
                return numA - numB;
              })
              .slice(0, options.maxFrames)
              .map((f) => join(outputDir, f));
            resolve(frameFiles);
          } catch (e) {
            reject(new Error(`Failed to list extracted frames: ${e}`));
          }
        } else {
          this.logger.error(`FFmpeg failed with code ${code}: ${stderr}`);
          reject(new Error(`FFmpeg extraction failed: ${stderr}`));
        }
      });

      ffmpeg.on('error', (err) => {
        reject(new Error(`Failed to spawn ffmpeg: ${err.message}`));
      });
    });
  }

  /**
   * Generate video thumbnail
   */
  async generateThumbnail(videoPath: string, outputPath: string, timeOffset = '00:00:01'): Promise<string> {
    return new Promise((resolve, reject) => {
      const ffmpeg = spawn('ffmpeg', [
        '-i', videoPath,
        '-ss', timeOffset,
        '-vframes', '1',
        '-vf', 'scale=320:240',
        '-y',
        outputPath,
      ]);

      let stderr = '';
      ffmpeg.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      ffmpeg.on('close', (code) => {
        if (code === 0) {
          resolve(outputPath);
        } else {
          reject(new Error(`Thumbnail generation failed: ${stderr}`));
        }
      });

      ffmpeg.on('error', (err) => {
        reject(new Error(`Failed to spawn ffmpeg: ${err.message}`));
      });
    });
  }

  /**
   * Get video metadata using FFprobe
   */
  async getVideoMetadata(videoPath: string): Promise<{
    duration: number;
    width: number;
    height: number;
    codec: string;
    bitrate: number;
    fps: number;
  }> {
    return new Promise((resolve, reject) => {
      const ffprobe = spawn('ffprobe', [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        videoPath,
      ]);

      let output = '';
      ffprobe.stdout.on('data', (data) => {
        output += data.toString();
      });

      ffprobe.on('close', (code) => {
        if (code === 0) {
          try {
            const data = JSON.parse(output);
            const videoStream = data.streams?.find((s: any) => s.codec_type === 'video');
            const format = data.format;

            resolve({
              duration: parseFloat(format?.duration || '0'),
              width: videoStream?.width || 0,
              height: videoStream?.height || 0,
              codec: videoStream?.codec_name || 'unknown',
              bitrate: parseInt(format?.bit_rate || '0', 10),
              fps: eval(videoStream?.r_frame_rate || '0/1'),
            });
          } catch (e) {
            reject(new Error(`Failed to parse ffprobe output: ${e}`));
          }
        } else {
          reject(new Error(`ffprobe exited with code ${code}`));
        }
      });

      ffprobe.on('error', (err) => {
        reject(new Error(`Failed to spawn ffprobe: ${err.message}`));
      });
    });
  }

  /**
   * Clean up temporary directory
   */
  async cleanupDirectory(dir: string): Promise<void> {
    try {
      await fs.rm(dir, { recursive: true, force: true });
    } catch (e) {
      this.logger.warn(`Failed to cleanup directory ${dir}: ${e}`);
    }
  }
}