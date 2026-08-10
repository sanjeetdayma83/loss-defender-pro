/** Strip sensitive fields outside development */
export function sanitizeForClient<T extends Record<string, any>>(
  data: T,
  fields: string[] = ['tempPassword', 'temporaryPassword', 'devCode', 'password', 'passwordHash'],
): T {
  if (process.env.NODE_ENV === 'production') {
    const copy = { ...data };
    for (const f of fields) {
      if (f in copy) delete copy[f];
    }
    return copy;
  }
  return data;
}

export function isProd() {
  return process.env.NODE_ENV === 'production';
}
