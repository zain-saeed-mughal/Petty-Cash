export async function deliverToDevices<T extends { token: string }>(
  devices: T[],
  deliveredTokens: Set<string>,
  send: (device: T) => Promise<boolean>,
  recordDelivered: (token: string) => Promise<void>,
): Promise<void> {
  for (const device of devices) {
    if (deliveredTokens.has(device.token)) continue;
    const accepted = await send(device);
    if (!accepted) continue;
    await recordDelivered(device.token);
    deliveredTokens.add(device.token);
  }
}
