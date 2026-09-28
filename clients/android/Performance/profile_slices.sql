-- profile_slices.sql isolates NewsBlur main-thread cell work and non-nested Choreographer frames.
WITH measured AS (
    SELECT s.id, s.ts, s.dur, tt.utid,
        CASE
            WHEN s.name GLOB 'RV onBindViewHolder*' THEN 'story bind'
            WHEN s.name GLOB 'RV onCreateViewHolder*' THEN 'story create'
            WHEN s.name = 'obtainView' THEN 'feed obtainView'
            WHEN s.name = 'setupListItem' THEN 'feed setupListItem'
            WHEN s.name = 'RV Scroll' THEN 'RV scroll'
            ELSE 'Choreographer frame'
        END AS operation
    FROM slice s
    JOIN thread_track tt ON s.track_id = tt.id
    JOIN thread t ON tt.utid = t.utid
    JOIN process p ON t.upid = p.upid
    WHERE p.name = 'com.newsblur' AND t.tid = p.pid AND s.dur > 0
        AND (s.name GLOB 'RV onBindViewHolder*'
            OR s.name GLOB 'RV onCreateViewHolder*'
            OR s.name IN ('obtainView', 'setupListItem', 'RV Scroll')
            OR s.name GLOB 'Choreographer#doFrame [0-9]*')
), with_cpu AS (
    SELECT measured.*,
        (SELECT SUM(MIN(cpu.ts + cpu.dur, measured.ts + measured.dur) - MAX(cpu.ts, measured.ts))
         FROM sched cpu
         WHERE cpu.utid = measured.utid AND cpu.dur > 0
             AND cpu.ts < measured.ts + measured.dur
             AND cpu.ts + cpu.dur > measured.ts) AS scheduled_cpu_ns
    FROM measured
)
SELECT operation, COUNT(*) AS samples,
    ROUND(AVG(dur) / 1e6, 3) AS mean_ms,
    ROUND(PERCENTILE(dur / 1e6, 50), 3) AS median_ms,
    ROUND(PERCENTILE(dur / 1e6, 95), 3) AS p95_ms,
    ROUND(MAX(dur) / 1e6, 3) AS max_ms,
    ROUND(AVG(scheduled_cpu_ns) / 1e6, 3) AS mean_scheduled_cpu_ms
FROM with_cpu
GROUP BY operation
ORDER BY operation;
