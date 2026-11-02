{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const loadingMsg = document.getElementById('loading-msg');
    if (loadingMsg) {
      loadingMsg.textContent = 'Arayüz motoru başlatılıyor...';
    }

    try {
      const appRunner = await engineInitializer.initializeEngine({
        canvasKitBaseUrl: 'canvaskit/',
      });

      if (loadingMsg) {
        loadingMsg.textContent = 'Uygulama açılıyor...';
      }

      // Smooth fade-out of the loading screen
      const loadingScreen = document.getElementById('loading-screen');
      if (loadingScreen) {
        loadingScreen.style.opacity = '0';
        setTimeout(() => {
          if (loadingScreen && loadingScreen.parentNode) {
            loadingScreen.parentNode.removeChild(loadingScreen);
          }
        }, 400);
      }

      await appRunner.runApp();
    } catch (err) {
      console.error('Flutter engine init error:', err);
      const errorBox = document.getElementById('error-box');
      if (errorBox) {
        errorBox.style.display = 'block';
        errorBox.innerHTML = '<strong>Arayüz motoru başlatılamadı.</strong><br/>Tarayıcınızın donanım hızlandırması veya WebGL desteği kapalı olabilir.<br/>Lütfen Chrome / Edge Ayarları &gt; Sistem &gt; <em>"Donanım hızlandırmayı kullan"</em> ayarını açıp sayfayı yenileyiniz.';
      }
      if (loadingMsg) {
        loadingMsg.textContent = 'Başlatma başarısız';
      }
    }
  }
});
