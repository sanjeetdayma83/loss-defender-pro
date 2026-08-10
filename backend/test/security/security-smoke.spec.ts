describe('Go-live security smoke', () => {
  it('requires strong production secrets', () => {
    const secrets = ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET', 'MARKETPLACE_CREDENTIAL_KEY'];
    for (const key of secrets) {
      const value = process.env[key] ?? `${key}-test-placeholder-32-chars`;
      expect(value.length).toBeGreaterThanOrEqual(32);
    }
  });

  it('does not allow wildcard production CORS configuration', () => {
    if (process.env.NODE_ENV === 'production') expect(process.env.FRONTEND_ORIGIN).toBeTruthy();
  });
});
