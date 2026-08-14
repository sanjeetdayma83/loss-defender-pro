export const QUEUE_FRAME_EXTRACTION = 'frame-extraction';

export interface FrameExtractionJobData {
  evidenceId: string;
  companyId: string;
  videoPath: string;
  options?: {
    maxFrames?: number;
    thumbnailSize?: string;
  };
}

export interface FrameExtractionJobResult {
  frameCount: number;
  frames: Array<{
    index: number;
    label: string;
    type: 'keyframe' | 'sample';
    path: string;
    size: number;
  }>;
  duration: number;
}