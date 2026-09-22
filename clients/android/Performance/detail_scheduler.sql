-- detail_scheduler.sql separates guest Android running, runnable, and sleeping time.
-- It does not measure host macOS scheduling; nested/concurrent slice totals are not additive.
CREATE PERFETTO TABLE app_threads AS
SELECT t.utid, t.name, t.tid, p.pid, CASE WHEN t.tid=p.pid THEN 'main' ELSE t.name END AS role
FROM thread t JOIN process p USING(upid) WHERE p.name='com.newsblur';
CREATE PERFETTO TABLE frames AS
SELECT s.id,s.ts,s.dur,tt.utid FROM slice s JOIN thread_track tt ON s.track_id=tt.id
JOIN app_threads t USING(utid)
WHERE t.role='main' AND s.name GLOB 'Choreographer#doFrame [0-9]*' AND s.dur>0;
SELECT 'main frame states' AS metric, st.state, COUNT(*) segments,
 ROUND(SUM(MIN(st.ts+st.dur,f.ts+f.dur)-MAX(st.ts,f.ts))/1e6,3) total_ms
FROM frames f JOIN thread_state st ON st.utid=f.utid AND st.dur>0 AND st.ts<f.ts+f.dur AND st.ts+st.dur>f.ts
GROUP BY st.state;
SELECT 'long frames' AS metric, f.id,ROUND((f.ts-b.start_ts)/1e9,3) sec,ROUND(f.dur/1e6,3) wall_ms,
 ROUND(SUM(CASE WHEN st.state='Running' THEN MIN(st.ts+st.dur,f.ts+f.dur)-MAX(st.ts,f.ts) ELSE 0 END)/1e6,3) running_ms,
 ROUND(SUM(CASE WHEN st.state GLOB 'R*' AND st.state!='Running' THEN MIN(st.ts+st.dur,f.ts+f.dur)-MAX(st.ts,f.ts) ELSE 0 END)/1e6,3) runnable_ms,
 ROUND(SUM(CASE WHEN st.state='S' THEN MIN(st.ts+st.dur,f.ts+f.dur)-MAX(st.ts,f.ts) ELSE 0 END)/1e6,3) sleeping_ms,
 ROUND((SELECT SUM(s.dur) FROM slice s JOIN thread_track tt ON s.track_id=tt.id
   WHERE tt.utid=f.utid AND s.name='postAndWait' AND s.ts>=f.ts AND s.ts+s.dur<=f.ts+f.dur)/1e6,3) graphics_wait_ms
FROM frames f JOIN trace_bounds b JOIN thread_state st ON st.utid=f.utid AND st.dur>0 AND st.ts<f.ts+f.dur AND st.ts+st.dur>f.ts
GROUP BY f.id ORDER BY f.dur DESC LIMIT 15;
SELECT 'thread states' AS metric,t.role,st.state,COUNT(*) segments,ROUND(SUM(st.dur)/1e6,3) total_ms,
 ROUND(MAX(st.dur)/1e6,3) longest_ms
FROM app_threads t JOIN thread_state st USING(utid) WHERE st.dur>0 AND t.role IN('main','RenderThread','VizWebView','Chrome_InProcGp')
GROUP BY t.role,st.state ORDER BY t.role,total_ms DESC;
SELECT 'render slices' AS metric,t.role,s.name,COUNT(*) samples,ROUND(SUM(s.dur)/1e6,3) total_ms,ROUND(MAX(s.dur)/1e6,3) max_ms
FROM app_threads t JOIN thread_track tt USING(utid) JOIN slice s ON s.track_id=tt.id
WHERE s.dur>0 AND t.role IN('RenderThread','VizWebView','Chrome_InProcGp')
GROUP BY t.role,s.name ORDER BY total_ms DESC LIMIT 35;
SELECT 'frame totals' AS metric,COUNT(*) samples,ROUND(SUM(dur)/1e6,3) total_ms FROM frames;
