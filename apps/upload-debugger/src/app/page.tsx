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
  cid?: string;
  gatewayUrl?: string;
  requestId?: string;
  duration?: number;
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
    priority: 'PRIMARY for public Vercel test',
    publicWeb: true,
  },
  {
    key: 'macmini',
    name: 'Mac Mini M4 Tailnet worker',
    url: 'https://minivlad.tail83ea3e.ts.net/video',
    priority: 'TAILNET candidate',
    publicWeb: false,
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

export default function Home() {
  const [username, setUsername] = useState('debug-user');
  const [file, setFile] = useState<File | null>(null);
  const [logs, setLogs] = useState<string[]>(['UI booted. Pick a video, then press Upload.']);
  const [stage, setStage] = useState('idle');
  const [progress, setProgress] = useState(0);
  const [result, setResult] = useState<UploadResult | null>(null);
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
    setResult(null);
    setProgress(0);
    setStage('starting');
    log(`starting upload: ${file.name} (${formatBytes(file.size)})`);

    for (const server of servers) {
      try {
        log(`checking ${server.priority}: ${server.name}`);
        await checkHealth(server);

        if (!server.publicWeb) {
          log(`skip ${server.key}: Tailnet host is not a reliable public-browser target from Vercel`);
          continue;
        }

        const requestId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;
        eventSourceRef.current?.close();

        const eventSource = new EventSource(`${server.url}/progress/${requestId}`);
        eventSourceRef.current = eventSource;
        eventSource.onopen = () => log(`progress stream connected: ${requestId}`);
        eventSource.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data) as { stage?: string; progress?: number };
            setStage(data.stage ?? 'progress');
            setProgress(Number(data.progress ?? 0));
            log(`progress ${data.progress ?? 0}% ${data.stage ?? 'unknown'}`);
          } catch {
            log(`progress raw: ${event.data}`);
          }
        };
        eventSource.onerror = () => log('progress stream error; upload may still continue');

        const formData = new FormData();
        formData.append('video', file);
        formData.append('creator', username || 'debug-user');
        formData.append('source_app', 'upload-debugger');
        formData.append('platform', 'web');
        formData.append('correlationId', requestId);

        setStage('uploading');
        log(`POST ${server.url}/transcode requestId=${requestId}`);

        const response = await fetch(`${server.url}/transcode`, {
          method: 'POST',
          body: formData,
        });
        const text = await response.text();
        eventSource.close();

        if (!response.ok) {
          log(`upload failed on ${server.key}: HTTP ${response.status} ${text.slice(0, 300)}`);
          continue;
        }

        const parsed = JSON.parse(text) as UploadResult;
        setResult(parsed);
        setStage('done');
        setProgress(100);
        log(`success on ${server.key}: ${parsed.cid ?? 'no cid in response'}`);
        setIsUploading(false);
        return;
      } catch (error) {
        log(`upload error on ${server.key}: ${error instanceof Error ? error.message : 'unknown error'}`);
      }
    }

    setStage('failed');
    setResult({ error: 'All servers failed. Check logs above.' });
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
            {isUploading ? 'Uploading...' : 'Upload'}
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
