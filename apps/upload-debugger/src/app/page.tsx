'use client';

import { ChangeEvent, useMemo, useRef, useState } from 'react';

type ServerTarget = {
  key: string;
  name: string;
  url: string;
  priority: string;
  publicWeb: boolean;
};

type UploadResult = {
  server?: string;
  ok?: boolean;
  cid?: string;
  gatewayUrl?: string;
  requestId?: string;
  duration?: number;
  elapsedMs?: number;
  creator?: string;
  sourceApp?: string;
  timestamp?: string;
  error?: string;
};

const servers: ServerTarget[] = [
  {
    key: 'oracle',
    name: 'Oracle public worker',
    url: 'https://transcode.skatehive.app',
    priority: 'PUBLIC Oracle baseline',
    publicWeb: true,
  },
  {
    key: 'macmini',
    name: 'Mac Mini M4 Tailnet worker',
    url: 'https://minivlad.tail83ea3e.ts.net/video',
    priority: 'Mac Mini speed candidate',
    publicWeb: true,
  },
  {
    key: 'pi',
    name: 'Raspberry Pi Tailnet worker',
    url: 'https://vladsberry.tail83ea3e.ts.net/video',
    priority: 'TAILNET fallback',
    publicWeb: false,
  },
];

const formatBytes = (bytes: number) => `${(bytes / 1024 / 1024).toFixed(2)} MB`;
const WORKER_TIMEOUT_MS = 10 * 60 * 1000;

export default function Home() {
  const [username, setUsername] = useState('debug-user');
  const [file, setFile] = useState<File | null>(null);
  const [logs, setLogs] = useState<string[]>(['UI booted. Pick a video, then press Upload.']);
  const [stage, setStage] = useState('idle');
  const [progress, setProgress] = useState(0);
  const [result, setResult] = useState<UploadResult[] | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const eventSourceRef = useRef<EventSource | null>(null);

  const selectedLabel = useMemo(() => {
    if (!file) return 'No file selected yet';
    return `${file.name} • ${formatBytes(file.size)} • ${file.type || 'unknown type'}`;
  }, [file]);

  const log = (message: string) => {
    const line = `[${new Date().toLocaleTimeString()}] ${message}`;
    setLogs((current) => [...current, line]);
    console.log('[upload-debugger]', message);
  };

  const onFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const selectedFile = event.target.files?.[0] ?? null;
    setFile(selectedFile);
    setResult(null);
    setProgress(0);
    setStage(selectedFile ? 'file selected' : 'idle');
    log(selectedFile ? `file selected: ${selectedFile.name} (${formatBytes(selectedFile.size)})` : 'file cleared');
  };

  const checkHealth = async (server: ServerTarget) => {
    const started = performance.now();
    const response = await fetch(`/api/video-proxy?url=${encodeURIComponent(`${server.url}/healthz`)}`, {
      cache: 'no-store',
    });
    const text = await response.text();
    const elapsed = Math.round(performance.now() - started);

    if (!response.ok) {
      throw new Error(`${response.status} ${text.slice(0, 180)}`);
    }

    log(`health ${server.key}: OK (${elapsed}ms)`);
    return text;
  };

  const testHealth = async () => {
    log('starting health checks');
    for (const server of servers) {
      try {
        await checkHealth(server);
      } catch (error) {
        log(`health ${server.key}: FAIL ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }
  };

  const testSse = () => {
    const server = servers[0];
    const requestId = `debug-${Date.now().toString(36)}`;
    eventSourceRef.current?.close();
    log(`opening SSE probe on ${server.key}, requestId=${requestId}`);

    const eventSource = new EventSource(`${server.url}/progress/${requestId}`);
    eventSourceRef.current = eventSource;

    const timer = window.setTimeout(() => {
      log('SSE probe closed after 8s');
      eventSource.close();
    }, 8000);

    eventSource.onopen = () => log('SSE connected');
    eventSource.onmessage = (event) => log(`SSE message: ${event.data}`);
    eventSource.onerror = () => {
      log('SSE error or blocked by CORS/network');
      window.clearTimeout(timer);
      eventSource.close();
    };
  };

  const upload = async () => {
    if (!file) {
      log('upload blocked: no file selected');
      setStage('choose a file first');
      return;
    }

    setIsUploading(true);
    setResult([]);
    setProgress(0);
    setStage('starting');
    const targets = servers.filter((server) => server.publicWeb);
    log(`starting benchmark upload to ${targets.map((server) => server.key).join(' + ')}: ${file.name} (${formatBytes(file.size)})`);

    const saveOutcome = (outcome: UploadResult) => {
      setResult((current) => [
        ...(current ?? []).filter((item) => item.server !== outcome.server),
        outcome,
      ]);
    };

    const uploadOne = async (server: ServerTarget): Promise<UploadResult> => {
      const started = performance.now();
      const controller = new AbortController();
      const timeout = window.setTimeout(() => controller.abort(), WORKER_TIMEOUT_MS);
      try {
        log(`checking ${server.priority}: ${server.name}`);
        await checkHealth(server);

        const requestId = `${server.key}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
        const eventSource = new EventSource(`${server.url}/progress/${requestId}`);
        eventSource.onopen = () => log(`${server.key}: progress stream connected ${requestId}`);
        eventSource.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data) as { stage?: string; progress?: number };
            log(`${server.key}: progress ${data.progress ?? 0}% ${data.stage ?? 'unknown'}`);
          } catch {
            log(`${server.key}: progress raw ${event.data}`);
          }
        };
        eventSource.onerror = () => log(`${server.key}: progress stream error; upload may still continue`);

        const formData = new FormData();
        formData.append('video', file);
        formData.append('creator', username || 'debug-user');
        formData.append('source_app', `upload-debugger-${server.key}`);
        formData.append('platform', 'web');
        formData.append('correlationId', requestId);

        log(`${server.key}: POST ${server.url}/transcode requestId=${requestId}`);
        const response = await fetch(`${server.url}/transcode`, {
          method: 'POST',
          body: formData,
          signal: controller.signal,
        });
        const text = await response.text();
        eventSource.close();
        window.clearTimeout(timeout);

        const elapsedMs = Math.round(performance.now() - started);
        if (!response.ok) {
          log(`${server.key}: failed HTTP ${response.status} after ${elapsedMs}ms ${text.slice(0, 300)}`);
          const outcome = { server: server.key, ok: false, elapsedMs, error: `HTTP ${response.status}: ${text.slice(0, 500)}` };
          saveOutcome(outcome);
          return outcome;
        }

        const parsed = JSON.parse(text) as UploadResult;
        log(`${server.key}: success in ${elapsedMs}ms ${parsed.cid ?? 'no cid in response'}`);
        const outcome = { ...parsed, server: server.key, ok: true, elapsedMs };
        saveOutcome(outcome);
        return outcome;
      } catch (error) {
        const elapsedMs = Math.round(performance.now() - started);
        window.clearTimeout(timeout);
        const message = error instanceof Error ? error.message : 'unknown error';
        const errorMessage = message.includes('abort') ? `Timed out after ${Math.round(WORKER_TIMEOUT_MS / 1000)}s` : message;
        log(`${server.key}: error after ${elapsedMs}ms ${errorMessage}`);
        const outcome = { server: server.key, ok: false, elapsedMs, error: errorMessage };
        saveOutcome(outcome);
        return outcome;
      }
    };

    setStage('benchmarking');
    setProgress(5);
    const outcomes = await Promise.all(targets.map(uploadOne));
    setResult(outcomes);
    setStage(outcomes.some((outcome) => outcome.ok) ? 'done' : 'failed');
    setProgress(100);
    setIsUploading(false);
  };

  const clear = () => {
    eventSourceRef.current?.close();
    setLogs(['Logs cleared.']);
    setResult(null);
    setStage('idle');
    setProgress(0);
  };

  return (
    <main className="container">
      <section className="hero">
        <p className="eyebrow">SkateHive temporary test</p>
        <h1>Upload Debugger</h1>
        <p>
          Public Vercel page for testing the transcoder before we touch the main app. It now logs every step instead of failing silently.
        </p>
      </section>

      <section className="panel">
        <label>
          Username
          <input value={username} onChange={(event) => setUsername(event.target.value)} />
        </label>

        <label>
          Video file
          <input type="file" accept="video/*,.mov,.MOV,.mp4,.MP4,.m4v,.M4V" onChange={onFileChange} />
        </label>
        <div className={file ? 'selected selectedReady' : 'selected'}>{selectedLabel}</div>

        <div className="actions">
          <button type="button" onClick={upload} disabled={isUploading || !file}>
            {isUploading ? 'Benchmarking...' : 'Upload to Oracle + Mac Mini'}
          </button>
          <button type="button" onClick={testHealth} disabled={isUploading}>Test health</button>
          <button type="button" onClick={testSse} disabled={isUploading}>Test SSE</button>
          <button type="button" onClick={clear}>Clear</button>
        </div>

        <div className="status">
          <span>Stage: {stage}</span>
          <span>{progress}%</span>
        </div>
        <progress value={progress} max={100} />
      </section>

      <section className="panel">
        <h2>Server order</h2>
        <ul>
          {servers.map((server) => (
            <li key={server.key}>
              <strong>{server.priority}</strong>: {server.name} → {server.url}
            </li>
          ))}
        </ul>
      </section>

      <section className="panel">
        <h2>Logs</h2>
        <pre className="logs">{logs.join('\n')}</pre>
      </section>

      <section className="panel">
        <h2>Result</h2>
        <pre className="result">{result ? JSON.stringify(result, null, 2) : 'No result yet'}</pre>
      </section>
    </main>
  );
}
