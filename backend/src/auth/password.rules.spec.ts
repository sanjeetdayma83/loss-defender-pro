describe("auth password rules", () => {
  const re = /(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/;
  it("rejects weak", () => {
    expect(re.test("weak")).toBe(false);
    expect(re.test("Test@12345")).toBe(true);
  });
});
