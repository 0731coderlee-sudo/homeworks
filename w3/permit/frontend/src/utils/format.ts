export function formatToken(v: bigint | null | undefined, decimals = 18, precision = 4) {
  if (v == null) return '—';
  const neg = v < 0n;
  const abs = neg ? -v : v;
  const s = abs.toString().padStart(decimals + 1, '0');
  const intPart = s.slice(0, -decimals) || '0';
  let frac = s.slice(-decimals).replace(/0+$/, '');
  if (precision >= 0) frac = frac.slice(0, precision);
  return (neg ? '-' : '') + (frac ? `${intPart}.${frac}` : intPart);
}
