import { parseCatalogImageUrl, jpegDimensions } from "../src/functions/catalog-images";

describe("parseCatalogImageUrl", () => {
  it("accepts only https cell/detail/zoom images on the Dunnes CDN", () => {
    expect(parseCatalogImageUrl("https://images.cdn.dunnesstoresgrocery.com/cell/100319104_1.jpg"))
      .toEqual({ sku: "100319104", index: "1" });
    expect(parseCatalogImageUrl("https://images.cdn.dunnesstoresgrocery.com/zoom/100319104_2.jpg"))
      .toEqual({ sku: "100319104", index: "2" });
  });
  it("rejects everything else", () => {
    for (const bad of [
      "http://images.cdn.dunnesstoresgrocery.com/cell/100319104_1.jpg",     // not https
      "https://evil.example.com/cell/100319104_1.jpg",                       // other host
      "https://images.cdn.dunnesstoresgrocery.com.evil.com/cell/1_1.jpg",    // host suffix trick
      "https://images.cdn.dunnesstoresgrocery.com/cell/../../etc/passwd",    // traversal
      "https://images.cdn.dunnesstoresgrocery.com/cell/100319104_1.png",     // not jpg
      "https://images.cdn.dunnesstoresgrocery.com/other/100319104_1.jpg",    // unknown variant
      "", null, undefined, 42,
    ]) {
      expect(parseCatalogImageUrl(bad)).toBeNull();
    }
  });
});

describe("jpegDimensions", () => {
  // SOI, APP0 (16 bytes), SOF0 with height 200 width 300, then SOS.
  const jpeg = Buffer.from([
    0xff, 0xd8,
    0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0xc8, 0x01, 0x2c, 0x01, 0x01, 0x11, 0x00,
    0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00,
  ]);
  it("reads width and height from the frame header", () => {
    expect(jpegDimensions(jpeg)).toEqual({ width: 300, height: 200 });
  });
  it("returns null for non-JPEG bytes and for a JPEG with no frame header", () => {
    expect(jpegDimensions(Buffer.from("not a jpeg"))).toBeNull();
    expect(jpegDimensions(Buffer.from([0x89, 0x50, 0x4e, 0x47]))).toBeNull();
    expect(jpegDimensions(Buffer.from([0xff, 0xd8, 0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00]))).toBeNull();
  });
});
