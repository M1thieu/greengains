-- Privacy by architecture: historical batches stored precise lat/lon in batch_json.
-- New uploads are rounded to 3 decimals (~110m) at ingest (upload.ts buildStoragePayload).
-- This scrubs existing rows to the same precision and drops bearing_deg (direction of
-- travel — nothing reads it). After this, nothing finer than zone level exists anywhere.
-- Idempotent: rounding already-rounded values is a no-op; missing keys are skipped.

UPDATE sensor_batches
SET batch_json = jsonb_set(
  jsonb_set(
    batch_json #- '{location,bearing_deg}',
    '{location,lat}',
    to_jsonb(ROUND((batch_json->'location'->>'lat')::numeric, 3))
  ),
  '{location,lon}',
  to_jsonb(ROUND((batch_json->'location'->>'lon')::numeric, 3))
)
WHERE batch_json->'location'->>'lat' IS NOT NULL
  AND batch_json->'location'->>'lon' IS NOT NULL;
