import assert from 'node:assert/strict';
import test from 'node:test';
import { deliverToDevices } from '../../supabase/functions/send-push/delivery.ts';

test('a failed later device does not resend to a device already recorded', async () => {
  const devices = [{ token: 'phone-a' }, { token: 'phone-b' }];
  const delivered = new Set();
  const attempts = [];
  let failB = true;
  const send = async (device) => {
    attempts.push(device.token);
    if (device.token === 'phone-b' && failB) {
      failB = false;
      throw new Error('Temporary FCM failure');
    }
    return true;
  };
  const record = async (token) => delivered.add(token);

  await assert.rejects(
    deliverToDevices(devices, delivered, send, record),
    /Temporary FCM failure/,
  );
  await deliverToDevices(devices, delivered, send, record);

  assert.deepEqual(attempts, ['phone-a', 'phone-b', 'phone-b']);
  assert.deepEqual([...delivered], ['phone-a', 'phone-b']);
});
