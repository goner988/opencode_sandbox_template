const http = require('http');
const https = require('https');

const PORT = 8500;
const TARGET_HOST = 'HOST_URL_PLACEHOLDER';

const server = http.createServer((req, res) => {
  const bodyChunks = [];

  req.on('data', chunk => {
    bodyChunks.push(chunk);
  });

  req.on('end', () => {
    const bodyBuffer = Buffer.concat(bodyChunks);
    let isQwen = false;

    try {
      if (bodyBuffer.length > 0) {
        const bodyJson = JSON.parse(bodyBuffer.toString('utf8'));

        if (bodyJson.model && bodyJson.model.toLowerCase().includes('qwen3.')) {
          isQwen = true;
        }
      }
    } catch (e) {
      // Suppress parse exceptions to avoid overhead.
    }

    const headers = { ...req.headers };
    headers.host = TARGET_HOST;

    const options = {
      hostname: TARGET_HOST,
      port: 443,
      path: req.url,
      method: req.method,
      headers: headers
    };

    const proxyReq = https.request(options, proxyRes => {
      const contentType = proxyRes.headers['content-type'] || '';
      const isStream = contentType.includes('text/event-stream');
      const isJson = contentType.includes('application/json');
      const shouldTransform = isQwen && (isStream || isJson);

      if (!shouldTransform) {
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(res);
        return;
      }

      // CASE 1: NON-STREAMING
      if (isJson) {
        let jsonBuffer = '';

        proxyRes.on('data', chunk => {
          jsonBuffer += chunk.toString('utf8');
        });

        proxyRes.on('end', () => {
          try {
            const resJson = JSON.parse(jsonBuffer);

            if (resJson.choices && resJson.choices[0] && resJson.choices[0].message) {
              const message = resJson.choices[0].message;
              const content = message.content || '';
              const hasNativeReasoning =
                (message.reasoning !== undefined && message.reasoning !== null) ||
                (message.reasoning_content !== undefined && message.reasoning_content !== null);

              if (!hasNativeReasoning) {
                let tag = '';

                if (content.includes('</thinking>')) {
                  tag = '</thinking>';
                } else if (content.includes('</think>')) {
                  tag = '</think>';
                }

                if (tag) {
                  const parts = content.split(tag);
                  let rawReasoning = parts[0];
                  const cleanContent = parts.slice(1).join(tag);

                  rawReasoning = rawReasoning
                    .replace('<thinking>', '')
                    .replace('<think>', '');

                  message.reasoning_content = rawReasoning;
                  message.content = cleanContent;
                }
              }
            }

            const outputBuffer = Buffer.from(JSON.stringify(resJson), 'utf8');
            const resHeaders = { ...proxyRes.headers };
            resHeaders['content-length'] = outputBuffer.length;

            res.writeHead(proxyRes.statusCode, resHeaders);
            res.end(outputBuffer);
          } catch (err) {
            res.writeHead(proxyRes.statusCode, proxyRes.headers);
            res.end(jsonBuffer);
          }
        });

        return;
      }

      // CASE 2: STREAMING
      res.writeHead(proxyRes.statusCode, proxyRes.headers);

      let responseBuffer = '';
      let inThinking = true;
      let totalText = '';
      let checkedResponseReasoning = false;
      let skipShiftingDueToResponse = false;

      proxyRes.on('data', (chunk) => {
        responseBuffer += chunk.toString('utf8');

        const lines = responseBuffer.split('\n');
        responseBuffer = lines.pop();

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            const dataStr = line.slice(6).trim();

            if (dataStr === '[DONE]') {
              res.write(line + '\n');
              continue;
            }

            try {
              const json = JSON.parse(dataStr);

              if (json.choices && json.choices[0] && json.choices[0].delta) {
                const delta = json.choices[0].delta;

                if (!checkedResponseReasoning) {
                  if (
                    (delta.reasoning !== undefined && delta.reasoning !== null) ||
                    (delta.reasoning_content !== undefined && delta.reasoning_content !== null)
                  ) {
                    skipShiftingDueToResponse = true;
                  }

                  checkedResponseReasoning = true;
                }

                if (!skipShiftingDueToResponse && typeof delta.content === 'string') {
                  if (inThinking) {
                    totalText += delta.content;

                    // Dynamic validation across both token structural layouts.
                    let tag = '';

                    if (totalText.includes('</thinking>')) {
                      tag = '</thinking>';
                    } else if (totalText.includes('</think>')) {
                      tag = '</think>';
                    }

                    if (tag) {
                      const previousLength = totalText.length - delta.content.length;
                      const endTagIndex = totalText.indexOf(tag);
                      const reasoningEnd = Math.max(0, endTagIndex - previousLength);
                      const reasoningPart = delta.content.slice(0, reasoningEnd);

                      const contentStart = Math.max(
                        0,
                        endTagIndex + tag.length - previousLength
                      );
                      const contentPart = delta.content.slice(contentStart);

                      delta.reasoning_content = reasoningPart;
                      delta.content = contentPart;

                      inThinking = false;
                    } else {
                      delta.reasoning_content = delta.content;
                      delta.content = '';
                    }
                  }

                  // When inThinking is false, delta.content is preserved verbatim.
                }
              }

              res.write('data: ' + JSON.stringify(json) + '\n');
            } catch (err) {
              res.write(line + '\n');
            }
          } else {
            res.write(line + '\n');
          }
        }
      });

      proxyRes.on('end', () => {
        if (responseBuffer) {
          res.write(responseBuffer);
        }

        res.end();
      });
    });

    proxyReq.on('error', (err) => {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Bridge Proxy Error: ' + err.message);
    });

    proxyReq.write(bodyBuffer);
    proxyReq.end();
  });
});

server.listen(PORT, () => {
  console.log(`Qwen CoT Bridge running on port ${PORT}`);
});
