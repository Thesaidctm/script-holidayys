const fs = require('fs');
const zlib = require('zlib');

const MMBLOCK_SIZE = 64;
const TILE_SIZE = 3;
const BLOCK_BYTES = MMBLOCK_SIZE * MMBLOCK_SIZE * TILE_SIZE;
const OTMM_SIGNATURE = 0x4d4d544f;
const MAX_Z = 15;
const UNKNOWN_TILE = [8, 12, 16, 255];

function clamp(value, min, max) {
    const number = Number(value);
    if (!Number.isFinite(number)) return min;
    return Math.max(min, Math.min(max, number));
}

function colorFrom8bit(color) {
    if (color >= 216 || color <= 0) return [0, 0, 0, 255];
    const r = Math.floor(color / 36) % 6 * 51;
    const g = Math.floor(color / 6) % 6 * 51;
    const b = color % 6 * 51;
    return [r, g, b, 255];
}

const palette = Array.from({ length: 256 }, (_, color) => {
    if (color === 255) return UNKNOWN_TILE;
    return colorFrom8bit(color);
});

function makeCrcTable() {
    const table = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
        let c = n;
        for (let k = 0; k < 8; k++) {
            c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
        }
        table[n] = c >>> 0;
    }
    return table;
}

const crcTable = makeCrcTable();

function crc32(buffer) {
    let crc = 0xffffffff;
    for (const byte of buffer) {
        crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
    }
    return (crc ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data = Buffer.alloc(0)) {
    const name = Buffer.from(type, 'ascii');
    const body = Buffer.concat([name, data]);
    const chunk = Buffer.alloc(12 + data.length);
    chunk.writeUInt32BE(data.length, 0);
    name.copy(chunk, 4);
    data.copy(chunk, 8);
    chunk.writeUInt32BE(crc32(body), 8 + data.length);
    return chunk;
}

function encodePng(width, height, rgba) {
    const rowBytes = width * 4;
    const raw = Buffer.alloc((rowBytes + 1) * height);

    for (let y = 0; y < height; y++) {
        const rawOffset = y * (rowBytes + 1);
        raw[rawOffset] = 0;
        rgba.copy(raw, rawOffset + 1, y * rowBytes, (y + 1) * rowBytes);
    }

    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(width, 0);
    ihdr.writeUInt32BE(height, 4);
    ihdr[8] = 8;
    ihdr[9] = 6;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;

    return Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        pngChunk('IHDR', ihdr),
        pngChunk('IDAT', zlib.deflateSync(raw, { level: 6 })),
        pngChunk('IEND')
    ]);
}

function readString(buffer, cursor) {
    const length = buffer.readUInt16LE(cursor.offset);
    cursor.offset += 2;
    const value = buffer.toString('utf8', cursor.offset, cursor.offset + length);
    cursor.offset += length;
    return value;
}

function parseOtmm(filePath) {
    const buffer = fs.readFileSync(filePath);
    const cursor = { offset: 0 };
    const signature = buffer.readUInt32LE(cursor.offset);
    cursor.offset += 4;

    if (signature !== OTMM_SIGNATURE) {
        throw new Error('Invalid OTMM minimap signature');
    }

    const start = buffer.readUInt16LE(cursor.offset);
    cursor.offset += 2;
    const version = buffer.readUInt16LE(cursor.offset);
    cursor.offset += 2;
    cursor.offset += 4;

    if (version !== 1) {
        throw new Error(`Unsupported OTMM minimap version: ${version}`);
    }

    readString(buffer, cursor);
    cursor.offset = start;

    const blocksByFloor = new Map();
    const floors = new Map();
    let blockCount = 0;

    while (cursor.offset + 5 <= buffer.length) {
        const x = buffer.readUInt16LE(cursor.offset);
        cursor.offset += 2;
        const y = buffer.readUInt16LE(cursor.offset);
        cursor.offset += 2;
        const z = buffer[cursor.offset++];

        if (x >= 65535 || y >= 65535 || z > MAX_Z) break;
        if (cursor.offset + 2 > buffer.length) break;

        const compressedLength = buffer.readUInt16LE(cursor.offset);
        cursor.offset += 2;
        if (cursor.offset + compressedLength > buffer.length) break;

        const compressed = buffer.subarray(cursor.offset, cursor.offset + compressedLength);
        cursor.offset += compressedLength;
        const tiles = zlib.inflateSync(compressed);
        if (tiles.length !== BLOCK_BYTES) break;

        if (!blocksByFloor.has(z)) blocksByFloor.set(z, new Map());
        blocksByFloor.get(z).set(`${x},${y}`, tiles);

        const floor = floors.get(z) || {
            z,
            minX: x,
            minY: y,
            maxX: x + MMBLOCK_SIZE - 1,
            maxY: y + MMBLOCK_SIZE - 1,
            blocks: 0
        };
        floor.minX = Math.min(floor.minX, x);
        floor.minY = Math.min(floor.minY, y);
        floor.maxX = Math.max(floor.maxX, x + MMBLOCK_SIZE - 1);
        floor.maxY = Math.max(floor.maxY, y + MMBLOCK_SIZE - 1);
        floor.blocks++;
        floors.set(z, floor);
        blockCount++;
    }

    return {
        blocksByFloor,
        floors: Array.from(floors.values()).sort((a, b) => a.z - b.z),
        blockCount
    };
}

function getBlockBase(value) {
    return Math.floor(value / MMBLOCK_SIZE) * MMBLOCK_SIZE;
}

function createOtmmMinimapService({ filePath }) {
    let parsed = null;
    let loadError = null;
    const viewCache = new Map();

    function ensureLoaded() {
        if (parsed || loadError) return;
        try {
            parsed = parseOtmm(filePath);
        } catch (error) {
            loadError = error;
        }
    }

    function getTileColor(x, y, z) {
        ensureLoaded();
        if (!parsed) return UNKNOWN_TILE;

        const floor = parsed.blocksByFloor.get(z);
        if (!floor) return UNKNOWN_TILE;

        const blockX = getBlockBase(x);
        const blockY = getBlockBase(y);
        const block = floor.get(`${blockX},${blockY}`);
        if (!block) return UNKNOWN_TILE;

        const localX = x - blockX;
        const localY = y - blockY;
        const tileIndex = (localY * MMBLOCK_SIZE + localX) * TILE_SIZE;
        const color = block[tileIndex + 1];
        return palette[color] || UNKNOWN_TILE;
    }

    function renderView({ x, y, z, width, height, scale }) {
        ensureLoaded();
        if (loadError) throw loadError;

        const centerX = Math.floor(clamp(x, 0, 65535));
        const centerY = Math.floor(clamp(y, 0, 65535));
        const floorZ = Math.floor(clamp(z, 0, MAX_Z));
        const imageWidth = Math.floor(clamp(width, 160, 1800));
        const imageHeight = Math.floor(clamp(height, 120, 1000));
        const pixelsPerTile = clamp(scale, 0.5, 8);
        const key = `${centerX}:${centerY}:${floorZ}:${imageWidth}:${imageHeight}:${pixelsPerTile}`;

        if (viewCache.has(key)) return viewCache.get(key);

        const rgba = Buffer.alloc(imageWidth * imageHeight * 4);
        const halfWidth = imageWidth / 2;
        const halfHeight = imageHeight / 2;

        for (let py = 0; py < imageHeight; py++) {
            const mapY = Math.floor(centerY + (py - halfHeight) / pixelsPerTile);
            for (let px = 0; px < imageWidth; px++) {
                const mapX = Math.floor(centerX + (px - halfWidth) / pixelsPerTile);
                const color = getTileColor(mapX, mapY, floorZ);
                const offset = (py * imageWidth + px) * 4;
                rgba[offset] = color[0];
                rgba[offset + 1] = color[1];
                rgba[offset + 2] = color[2];
                rgba[offset + 3] = color[3];
            }
        }

        const png = encodePng(imageWidth, imageHeight, rgba);
        viewCache.set(key, png);
        if (viewCache.size > 120) {
            viewCache.delete(viewCache.keys().next().value);
        }
        return png;
    }

    function getMeta() {
        ensureLoaded();
        return {
            loaded: Boolean(parsed),
            error: loadError ? loadError.message : null,
            file: filePath,
            blockSize: MMBLOCK_SIZE,
            blocks: parsed?.blockCount || 0,
            floors: parsed?.floors || []
        };
    }

    return {
        getMeta,
        renderView
    };
}

module.exports = {
    createOtmmMinimapService
};
