declare module 'rxjs' {
  export class Observable<T = any> {
    subscribe(next?: any, error?: any, complete?: any): any;
    pipe(...ops: any[]): Observable<T>;
    toPromise(): Promise<T>;
  }
  export type OperatorFunction<T, R> = (source: Observable<T>) => Observable<R>;
  export function map(fn: any): any;
  export function tap(fn: any): any;
  export function catchError(fn: any): any;
  export function switchMap(fn: any): any;
  export function mergeMap(fn: any): any;
  export function finalize(fn: any): any;
  export function filter(fn: any): any;
  export function take(n: number): any;
  export function of(...a: any[]): Observable<any>;
  export function from(a: any): Observable<any>;
  export function throwError(a: any): Observable<any>;
  export function firstValueFrom<T>(o: Observable<T>): Promise<T>;
  export function lastValueFrom<T>(o: Observable<T>): Promise<T>;
}
declare module 'rxjs/operators' {
  export function map(fn: any): any;
  export function tap(fn: any): any;
  export function catchError(fn: any): any;
  export function switchMap(fn: any): any;
  export function mergeMap(fn: any): any;
  export function finalize(fn: any): any;
  export function filter(fn: any): any;
  export function take(n: number): any;
}