import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const sourcePath = join(root, 'output', 'app-icon', 'daming-icon-mingshu-1024.png');
const outputDir = join(root, 'output', 'app-icon', 'comfyui');
const server = 'http://127.0.0.1:8188';
await mkdir(outputDir, { recursive: true });

const promptPositive = [
  'iOS app icon design, one single huge Chinese character "明" only,',
  'authentic wild cursive Chinese calligraphy, bold commanding brushwork,',
  'dramatic sweeping strokes, visible dry-brush texture, confident calligraphic gesture,',
  'warm ivory ink on deep vermilion cinnabar red background,',
  'centered square composition, powerful negative space, readable at small icon size,',
  'flat graphic surface, crisp silhouette, no other words, no border, no seal'
].join(' ');
const promptNegative = [
  'two characters, 大明, extra Chinese characters, any other text, English letters,',
  'watermark, signature, logo text, frame, border, seal, mockup, phone, paper sheet,',
  'multiple glyphs, ornaments, scenery, flowers, mountains, 3d, glow, neon, blurry,',
  'cropped character, illegible, thin strokes, decorative noise'
].join(' ');

async function uploadSource() {
  const bytes = await readFile(sourcePath);
  const form = new FormData();
  form.append('image', new Blob([bytes], { type: 'image/png' }), 'daming-ming-source.png');
  form.append('type', 'input');
  const response = await fetch(`${server}/upload/image`, { method: 'POST', body: form });
  if (!response.ok) throw new Error(`Upload failed: ${response.status}`);
  return response.json();
}

async function queueWorkflow(imageName, seed, denoise, index) {
  const workflow = {
    '1': {
      class_type: 'CheckpointLoaderSimple',
      inputs: { ckpt_name: 'sd_xl_base_1.0.safetensors' }
    },
    '2': {
      class_type: 'LoadImage',
      inputs: { image: imageName }
    },
    '3': {
      class_type: 'CLIPTextEncode',
      inputs: { text: promptPositive, clip: ['1', 1] }
    },
    '4': {
      class_type: 'CLIPTextEncode',
      inputs: { text: promptNegative, clip: ['1', 1] }
    },
    '5': {
      class_type: 'VAEEncode',
      inputs: { pixels: ['2', 0], vae: ['1', 2] }
    },
    '6': {
      class_type: 'KSampler',
      inputs: {
        seed,
        steps: 28,
        cfg: 6.0,
        sampler_name: 'dpmpp_2m',
        scheduler: 'karras',
        denoise,
        model: ['1', 0],
        positive: ['3', 0],
        negative: ['4', 0],
        latent_image: ['5', 0]
      }
    },
    '7': {
      class_type: 'VAEDecode',
      inputs: { samples: ['6', 0], vae: ['1', 2] }
    },
    '8': {
      class_type: 'SaveImage',
      inputs: { images: ['7', 0], filename_prefix: `daming-ming-comfy-${index}` }
    }
  };
  const response = await fetch(`${server}/prompt`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ prompt: workflow, client_id: `daming-icon-${Date.now()}-${index}` })
  });
  if (!response.ok) throw new Error(`Queue failed: ${response.status} ${await response.text()}`);
  return response.json();
}

async function waitForResult(promptId) {
  for (let attempt = 0; attempt < 600; attempt += 1) {
    await new Promise((done) => setTimeout(done, 500));
    const response = await fetch(`${server}/history/${promptId}`);
    if (!response.ok) continue;
    const history = await response.json();
    const entry = history[promptId];
    if (!entry) continue;
    if (entry.status?.status_str === 'error') throw new Error(JSON.stringify(entry.status));
    const images = Object.values(entry.outputs || {}).flatMap((output) => output.images || []);
    if (images.length) return images[0];
  }
  throw new Error(`Timed out waiting for ${promptId}`);
}

async function downloadImage(image, index) {
  const query = new URLSearchParams({
    filename: image.filename,
    subfolder: image.subfolder || '',
    type: image.type || 'output'
  });
  const response = await fetch(`${server}/view?${query}`);
  if (!response.ok) throw new Error(`Download failed: ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  const path = join(outputDir, `daming-ming-comfy-${index}.png`);
  await writeFile(path, bytes);
  return path;
}

const upload = await uploadSource();
const variants = [
  { seed: 271, denoise: 0.54 },
  { seed: 1449, denoise: 0.64 },
  { seed: 1644, denoise: 0.74 }
];
const results = [];
for (let index = 0; index < variants.length; index += 1) {
  const variant = variants[index];
  const queued = await queueWorkflow(upload.name, variant.seed, variant.denoise, index + 1);
  const image = await waitForResult(queued.prompt_id);
  const path = await downloadImage(image, index + 1);
  results.push({ ...variant, promptId: queued.prompt_id, image, path });
  console.log(`Generated ${index + 1}/${variants.length}: ${path}`);
}

const manifest = {
  generatedAt: new Date().toISOString(),
  source: basename(sourcePath),
  checkpoint: 'sd_xl_base_1.0.safetensors',
  positivePrompt: promptPositive,
  negativePrompt: promptNegative,
  variants: results
};
await writeFile(join(outputDir, 'generation.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(JSON.stringify(manifest, null, 2));
