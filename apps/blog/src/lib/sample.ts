// The shared trace sample (kwatch README, "An example trace"). Used when a post
// has no `output` of its own, in the featured card and the og image.
export const sampleTrace = `Pod checkout-api-7f9c          CrashLoopBackOff
  Deployment checkout-api      healthy before 03:03
    Node worker-3              healthy
      ConfigMap checkout-config  changed 03:03   <- cause`;

/** Index of the line to emphasise: the one marked as the cause. */
export function causeLines(text: string): number[] {
  return text.split('\n').flatMap((l, i) => (l.includes('<- cause') ? [i] : []));
}
