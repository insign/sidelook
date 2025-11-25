// lib/src/html_assets.dart

/// Gera o HTML completo da página do visualizador
///
/// [wsPort] - Porta para conexão WebSocket
/// [initialImage] - Caminho da imagem inicial (null = aguardando)
String generateHtml({
  required int wsPort,
  String? initialImage,
}) {
  final imageDisplay = initialImage != null
      ? '<img id="viewer" src="/image/$initialImage" alt="Imagem">'
      : '<div id="waiting">Aguardando primeira imagem...</div>';

  return '''
<!DOCTYPE html>
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
      width: 100%;
      height: 100%;
      background: #000;
      overflow: hidden;
    }

    #container {
      width: 100%;
      height: 100%;
      display: flex;
      justify-content: center;
      align-items: center;
      cursor: pointer;
    }

    #viewer {
      max-width: 100%;
      max-height: 100%;
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

    /* Fullscreen styles */
    :fullscreen #container,
    :-webkit-full-screen #container {
      background: #000;
    }
  </style>
</head>
<body>
  <div id="container" onclick="toggleFullscreen()">
    $imageDisplay
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
      // Usar mesmo host que a página
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

      // Se estava no estado "aguardando", remover mensagem
      if (waiting) {
        waiting.remove();
      }

      if (current) {
        // Fade out
        current.classList.add('fade-out');

        setTimeout(() => {
          // Criar nova imagem
          const newImg = document.createElement('img');
          newImg.id = 'viewer';
          // Adicionar timestamp para evitar cache
          newImg.src = '/image/' + imagePath + '?t=' + Date.now();
          newImg.alt = 'Imagem';
          newImg.classList.add('fade-out');

          newImg.onload = () => {
            current.remove();
            container.appendChild(newImg);
            // Trigger reflow para animação funcionar
            void newImg.offsetWidth;
            newImg.classList.remove('fade-out');
          };

          newImg.onerror = () => {
            console.error('Erro ao carregar imagem:', imagePath);
          };
        }, 200);
      } else {
        // Primeira imagem
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

    // Atalho de teclado: F para fullscreen, Escape para sair
    document.addEventListener('keydown', (e) => {
      if (e.key === 'f' || e.key === 'F') {
        toggleFullscreen();
      }
    });

    // Iniciar conexão
    connect();
  </script>
</body>
</html>
''';
}
