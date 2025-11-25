// internal/assets/html.go
package assets

import "fmt"

// GenerateHTML gera o HTML completo da página do visualizador
func GenerateHTML(initialImage string) string {
	imageDisplay := `<div id="waiting">Aguardando primeira imagem...</div>`
	if initialImage != "" {
		imageDisplay = fmt.Sprintf(`<img id="viewer" src="/image/%s" alt="Imagem">`, initialImage)
	}

	return fmt.Sprintf(`<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>sidelook</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    html, body {
      width: 100%%;
      height: 100%%;
      background: #000;
      overflow: hidden;
    }

    #container {
      width: 100%%;
      height: 100%%;
      display: flex;
      justify-content: center;
      align-items: center;
      cursor: pointer;
    }

    #viewer {
      max-width: 100%%;
      max-height: 100%%;
      object-fit: contain;
      opacity: 1;
      transform: scale(1);
      transition: opacity 200ms ease-out, transform 200ms ease-out;
    }

    #viewer.fade-out {
      opacity: 0;
      transform: scale(0.98);
    }

    #waiting {
      color: #666;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      font-size: 1.5rem;
      text-align: center;
      padding: 2rem;
    }

    #status {
      position: fixed;
      bottom: 10px;
      right: 10px;
      padding: 5px 10px;
      border-radius: 4px;
      font-family: monospace;
      font-size: 12px;
      opacity: 0.7;
      transition: opacity 0.3s;
    }

    #status:hover {
      opacity: 1;
    }

    #status.connected {
      background: #1a472a;
      color: #4ade80;
    }

    #status.disconnected {
      background: #4a1a1a;
      color: #f87171;
    }

    :fullscreen #container,
    :-webkit-full-screen #container {
      background: #000;
    }
  </style>
</head>
<body>
  <div id="container" onclick="toggleFullscreen()">
    %s
  </div>
  <div id="status" class="disconnected">Desconectado</div>

  <script>
    const container = document.getElementById('container');
    const status = document.getElementById('status');
    let ws;
    let reconnectAttempts = 0;
    const maxReconnectAttempts = 10;
    const reconnectDelay = 2000;

    function connect() {
      const wsUrl = 'ws://' + window.location.host + '/ws';
      ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        console.log('WebSocket conectado');
        status.textContent = 'Conectado';
        status.className = 'connected';
        reconnectAttempts = 0;
      };

      ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.type === 'new_image') {
          updateImage(data.path);
        }
      };

      ws.onclose = () => {
        console.log('WebSocket desconectado');
        status.textContent = 'Desconectado';
        status.className = 'disconnected';
        scheduleReconnect();
      };

      ws.onerror = (error) => {
        console.error('WebSocket erro:', error);
      };
    }

    function scheduleReconnect() {
      if (reconnectAttempts < maxReconnectAttempts) {
        reconnectAttempts++;
        console.log('Tentando reconectar... (' + reconnectAttempts + '/' + maxReconnectAttempts + ')');
        setTimeout(connect, reconnectDelay);
      }
    }

    function updateImage(imagePath) {
      const current = document.getElementById('viewer');
      const waiting = document.getElementById('waiting');

      if (waiting) {
        waiting.remove();
      }

      if (current) {
        current.classList.add('fade-out');

        setTimeout(() => {
          const newImg = document.createElement('img');
          newImg.id = 'viewer';
          newImg.src = '/image/' + imagePath + '?t=' + Date.now();
          newImg.alt = 'Imagem';
          newImg.classList.add('fade-out');

          newImg.onload = () => {
            current.remove();
            container.appendChild(newImg);
            void newImg.offsetWidth;
            newImg.classList.remove('fade-out');
          };

          newImg.onerror = () => {
            console.error('Erro ao carregar imagem:', imagePath);
          };
        }, 200);
      } else {
        const newImg = document.createElement('img');
        newImg.id = 'viewer';
        newImg.src = '/image/' + imagePath + '?t=' + Date.now();
        newImg.alt = 'Imagem';
        container.appendChild(newImg);
      }
    }

    function toggleFullscreen() {
      if (!document.fullscreenElement) {
        container.requestFullscreen().catch(err => {
          console.log('Erro ao entrar em fullscreen:', err);
        });
      } else {
        document.exitFullscreen();
      }
    }

    document.addEventListener('keydown', (e) => {
      if (e.key === 'f' || e.key === 'F') {
        toggleFullscreen();
      }
    });

    connect();
  </script>
</body>
</html>
`, imageDisplay)
}
