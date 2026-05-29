/**
 * Adaptive multi-image grid layout using binary slicing trees (guillotine cuts).
 *
 * Enumerates all valid slicing trees for up to 6 images, evaluates each via
 * closed-form DP to find optimal cut ratios, and selects the tree with minimum
 * total log-aspect-ratio distortion.
 *
 * Produces pixel-level (x, y, width, height) rects for each image.
 */

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ImageInput {
  /** width / height. Must be > 0. */
  aspectRatio: number;
}

export interface LayoutRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface LayoutOptions {
  containerWidth: number;
  /** Maximum allowed height. The layout adapts to image content below this cap. */
  maxHeight: number;
  /** Gap between images in px. Default 2. */
  gap?: number;
  /** Minimum width per image cell in px. Default 60. */
  minWidth?: number;
  /** Minimum height per image cell in px. Default 60. */
  minHeight?: number;
}

interface SlicingTree {
  id: string;
  type: 'leaf' | 'v' | 'h';
  /** Leaf index into the images array. */
  index?: number;
  left?: SlicingTree;
  right?: SlicingTree;
}

interface NodeEval {
  mu: number;
  weight: number;
  arEff: number;
  rOpt: number;
  minW: number;
  minH: number;
  valid: boolean;
}

const INVALID_NODE: NodeEval = {
  mu: 0,
  weight: 0,
  arEff: 1,
  rOpt: 0.5,
  minW: 0,
  minH: 0,
  valid: false,
};

/** Never allocate less than 5% of available space to either side of a cut. */
const MIN_CUT_RATIO = 0.05;
const MAX_CUT_RATIO = 0.95;

/** Floor for aspect ratio to avoid degenerate layouts from zero/negative values. */
const MIN_ASPECT_RATIO = 0.01;

/** Re-evaluate constraints only when actual height differs from maxHeight by more than this. */
const HEIGHT_REEVAL_THRESHOLD = 0.5;

// ---------------------------------------------------------------------------
// Tree enumeration
// ---------------------------------------------------------------------------

function generateTrees(start: number, end: number): SlicingTree[] {
  if (start === end) {
    return [{ id: `L${start}`, type: 'leaf', index: start }];
  }
  const trees: SlicingTree[] = [];
  for (let split = start; split < end; split++) {
    const leftTrees = generateTrees(start, split);
    const rightTrees = generateTrees(split + 1, end);
    for (const left of leftTrees) {
      for (const right of rightTrees) {
        const lid = left.id;
        const rid = right.id;
        trees.push({ id: `V(${lid},${rid})`, type: 'v', left, right });
        trees.push({ id: `H(${lid},${rid})`, type: 'h', left, right });
      }
    }
  }
  return trees;
}

function generateSlicingTrees(n: number): SlicingTree[] {
  if (n <= 0) return [];
  return generateTrees(0, n - 1);
}

// ---------------------------------------------------------------------------
// Bottom-up evaluation
// ---------------------------------------------------------------------------

function computeCutParams(
  direction: 'v' | 'h',
  leftEval: NodeEval,
  rightEval: NodeEval,
  containerW: number,
  containerH: number,
  gap: number,
): { rOpt: number; muNode: number; nodeMinW: number; nodeMinH: number; valid: boolean } {
  const aL = Math.exp(leftEval.mu);
  const aR = Math.exp(rightEval.mu);
  const wTotal = leftEval.weight + rightEval.weight;
  const muNode = (leftEval.weight * leftEval.mu + rightEval.weight * rightEval.mu) / wTotal;

  const rOptRaw =
    direction === 'v'
      ? (leftEval.weight * aL) / (leftEval.weight * aL + rightEval.weight * aR)
      : leftEval.weight / aL / (leftEval.weight / aL + rightEval.weight / aR);

  const usable = direction === 'v' ? containerW - gap : containerH - gap;
  const sizeField = direction === 'v' ? 'minW' : 'minH';
  const rMin = Math.max(MIN_CUT_RATIO, leftEval[sizeField] / usable);
  const rMax = Math.min(MAX_CUT_RATIO, (usable - rightEval[sizeField]) / usable);

  if (rMin > rMax) {
    return { rOpt: 0.5, muNode: 0, nodeMinW: 0, nodeMinH: 0, valid: false };
  }

  const rOpt = Math.max(rMin, Math.min(rMax, rOptRaw));

  const nodeMinW = direction === 'v' ? leftEval.minW + gap + rightEval.minW : Math.max(leftEval.minW, rightEval.minW);
  const nodeMinH = direction === 'v' ? Math.max(leftEval.minH, rightEval.minH) : leftEval.minH + gap + rightEval.minH;

  return { rOpt, muNode, nodeMinW, nodeMinH, valid: true };
}

function evaluateNode(
  node: SlicingTree,
  images: ImageInput[],
  w: number,
  h: number,
  gap: number,
  minW: number,
  minH: number,
  out: Map<string, NodeEval>,
): boolean {
  if (node.type === 'leaf' && node.index !== undefined) {
    const ar = Math.max(MIN_ASPECT_RATIO, images[node.index].aspectRatio);
    const leafEval: NodeEval = {
      mu: Math.log(ar),
      weight: 1,
      arEff: ar,
      rOpt: 1,
      minW,
      minH,
      valid: w >= minW && h >= minH,
    };
    out.set(node.id, leafEval);
    return leafEval.valid;
  }

  const leftOk = evaluateNode(node.left!, images, w, h, gap, minW, minH, out);
  const rightOk = evaluateNode(node.right!, images, w, h, gap, minW, minH, out);

  if (!leftOk || !rightOk) {
    out.set(node.id, INVALID_NODE);
    return false;
  }

  const leftEval = out.get(node.left!.id)!;
  const rightEval = out.get(node.right!.id)!;
  const { rOpt, muNode, nodeMinW, nodeMinH, valid } = computeCutParams(
    node.type as 'v' | 'h',
    leftEval,
    rightEval,
    w,
    h,
    gap,
  );

  if (!valid) {
    out.set(node.id, INVALID_NODE);
    return false;
  }

  out.set(node.id, {
    mu: muNode,
    weight: leftEval.weight + rightEval.weight,
    arEff: Math.exp(muNode),
    rOpt,
    minW: nodeMinW,
    minH: nodeMinH,
    valid: true,
  });
  return true;
}

// ---------------------------------------------------------------------------
// Top-down distortion
// ---------------------------------------------------------------------------

function computeDistortion(
  node: SlicingTree,
  nodeMap: Map<string, NodeEval>,
  images: ImageInput[],
  w: number,
  h: number,
  gap: number,
): number {
  if (node.type === 'leaf' && node.index !== undefined) {
    const ar = Math.max(0.01, images[node.index].aspectRatio);
    const actualAR = w / h;
    const lnRatio = Math.log(actualAR / ar);
    return lnRatio * lnRatio;
  }

  const nodeEval = nodeMap.get(node.id)!;
  const cutRatio = nodeEval.rOpt;

  if (node.type === 'v') {
    const lw = (w - gap) * cutRatio;
    const rw = w - gap - lw;
    return (
      computeDistortion(node.left!, nodeMap, images, lw, h, gap) +
      computeDistortion(node.right!, nodeMap, images, rw, h, gap)
    );
  } else {
    const th = (h - gap) * cutRatio;
    const bh = h - gap - th;
    return (
      computeDistortion(node.left!, nodeMap, images, w, th, gap) +
      computeDistortion(node.right!, nodeMap, images, w, bh, gap)
    );
  }
}

// ---------------------------------------------------------------------------
// Tree to layout
// ---------------------------------------------------------------------------

function treeToLayout(
  node: SlicingTree,
  nodeMap: Map<string, NodeEval>,
  rect: { x: number; y: number; w: number; h: number },
  gap: number,
  out: LayoutRect[],
): void {
  if (node.type === 'leaf') {
    out.push({ x: rect.x, y: rect.y, width: rect.w, height: rect.h });
    return;
  }

  const nodeEval = nodeMap.get(node.id)!;
  const cutRatio = nodeEval.rOpt;

  if (node.type === 'v') {
    const lw = (rect.w - gap) * cutRatio;
    treeToLayout(node.left!, nodeMap, { x: rect.x, y: rect.y, w: lw, h: rect.h }, gap, out);
    treeToLayout(node.right!, nodeMap, { x: rect.x + lw + gap, y: rect.y, w: rect.w - lw - gap, h: rect.h }, gap, out);
  } else {
    const th = (rect.h - gap) * cutRatio;
    treeToLayout(node.left!, nodeMap, { x: rect.x, y: rect.y, w: rect.w, h: th }, gap, out);
    treeToLayout(node.right!, nodeMap, { x: rect.x, y: rect.y + th + gap, w: rect.w, h: rect.h - th - gap }, gap, out);
  }
}

// ---------------------------------------------------------------------------
// Fallback grid
// ---------------------------------------------------------------------------

function fallbackGrid(n: number, w: number, h: number, gap: number): LayoutRect[] {
  const cols = n <= 2 ? n : n <= 4 ? 2 : 3;
  const rows = Math.ceil(n / cols);
  const cellW = (w - gap * (cols - 1)) / cols;
  const cellH = (h - gap * (rows - 1)) / rows;
  const rects: LayoutRect[] = [];
  for (let i = 0; i < n; i++) {
    rects.push({
      x: (i % cols) * (cellW + gap),
      y: Math.floor(i / cols) * (cellH + gap),
      width: cellW,
      height: cellH,
    });
  }
  return rects;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Compute an adaptive grid layout for 2–6 images using slicing trees.
 *
 * Container height adapts to image content, never exceeding `maxHeight`.
 * Returns both the layout rects and the actual height used.
 */
export function computeMultiImageLayout(
  images: ImageInput[],
  options: LayoutOptions,
): { rects: LayoutRect[]; height: number } {
  const n = images.length;
  const gap = options.gap ?? 2;
  const minW = options.minWidth ?? 60;
  const minH = options.minHeight ?? 60;
  const cw = options.containerWidth;
  const maxHeight = options.maxHeight;

  if (n === 1) {
    const ar = Math.max(MIN_ASPECT_RATIO, images[0].aspectRatio);
    const height = Math.min(cw / ar, maxHeight);
    return { rects: [{ x: 0, y: 0, width: cw, height }], height };
  }

  const trees = generateSlicingTrees(n);
  let bestDist = Infinity;
  let bestTree: SlicingTree | null = null;
  let bestMap: Map<string, NodeEval> | null = null;
  let bestHeight = maxHeight;

  for (const tree of trees) {
    // First pass: evaluate at maxHeight to extract arEff and check validity.
    const nodeMap = new Map<string, NodeEval>();
    if (!evaluateNode(tree, images, cw, maxHeight, gap, minW, minH, nodeMap)) continue;

    // arEff is intrinsic to the tree structure and image aspect ratios.
    const arEff = nodeMap.get(tree.id)!.arEff;
    const naturalHeight = cw / arEff;
    const actualHeight = Math.min(naturalHeight, maxHeight);

    // If shorter than maxHeight, re-evaluate at actual height so that
    // constraint clamping (minH) reflects the real container dimensions.
    let finalMap = nodeMap;
    if (actualHeight < maxHeight - HEIGHT_REEVAL_THRESHOLD) {
      const reevalMap = new Map<string, NodeEval>();
      if (!evaluateNode(tree, images, cw, actualHeight, gap, minW, minH, reevalMap)) continue;
      finalMap = reevalMap;
    }

    const dist = computeDistortion(tree, finalMap, images, cw, actualHeight, gap);

    if (dist < bestDist) {
      bestDist = dist;
      bestTree = tree;
      bestMap = finalMap;
      bestHeight = actualHeight;
    }
  }

  if (bestTree && bestMap) {
    const rects: LayoutRect[] = [];
    treeToLayout(bestTree, bestMap, { x: 0, y: 0, w: cw, h: bestHeight }, gap, rects);
    return { rects, height: bestHeight };
  }

  // Fallback: uniform grid at maxHeight.
  return { rects: fallbackGrid(n, cw, maxHeight, gap), height: maxHeight };
}
