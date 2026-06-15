import { NextRequest, NextResponse } from 'next/server';

const ALLOWED_HOSTS = new Set([
  'minivlad.tail83ea3e.ts.net',
  'transcode.skatehive.app',
  'vladsberry.tail83ea3e.ts.net',
]);

export async function GET(request: NextRequest) {
  const target = request.nextUrl.searchParams.get('url');
  if (!target) return NextResponse.json({ error: 'Missing url' }, { status: 400 });

  let parsed: URL;
  try {
    parsed = new URL(target);
  } catch {
    return NextResponse.json({ error: 'Invalid url' }, { status: 400 });
  }

  if (!ALLOWED_HOSTS.has(parsed.hostname)) {
    return NextResponse.json({ error: 'Host not allowed' }, { status: 403 });
  }

  try {
    const response = await fetch(parsed.toString(), {
      headers: { Origin: 'https://skatehive.app' },
      cache: 'no-store',
      signal: AbortSignal.timeout(10000),
    });

    const body = await response.text();
    return new NextResponse(body, {
      status: response.status,
      headers: { 'content-type': response.headers.get('content-type') || 'application/json' },
    });
  } catch (error) {
    return NextResponse.json({ error: error instanceof Error ? error.message : 'Proxy failed' }, { status: 502 });
  }
}
