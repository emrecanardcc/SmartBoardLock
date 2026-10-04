using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using WinForms = System.Windows.Forms;

namespace KioskLockApp.UI
{
    public class FloatingLockButtonForm : Window
    {
        public Action OnLockRequested;

        private Border mainBorder;
        private TextBlock txtLabel;
        private TextBlock iconLabel;

        private readonly double expandedWidth = 200;
        private readonly double collapsedWidth = 64;
        private readonly double widgetHeight = 64;

        private bool isExpanded = true;
        private bool isDragging = false;

        // YENİ: Global Fare Takibi (WPF kilitlenmelerini önler)
        private System.Drawing.Point dragStartMousePos;
        private double dragStartWindowLeft;
        private double dragStartWindowTop;

        private System.Windows.Threading.DispatcherTimer collapseTimer;

        public FloatingLockButtonForm()
        {
            this.WindowStyle = WindowStyle.None;
            this.AllowsTransparency = true;
            this.Background = System.Windows.Media.Brushes.Transparent;

            // HER ZAMAN EN ÜSTTE
            this.Topmost = true;
            this.ShowInTaskbar = false;
            this.SizeToContent = SizeToContent.WidthAndHeight;

            var workArea = WinForms.Screen.PrimaryScreen.WorkingArea;
            this.Left = workArea.Right - expandedWidth - 20;
            this.Top = (workArea.Height - widgetHeight) / 2;

            mainBorder = new Border
            {
                Width = expandedWidth,
                Height = widgetHeight,
                Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(37, 99, 235)),
                CornerRadius = new CornerRadius(32),
                Margin = new Thickness(20),
                Effect = new DropShadowEffect
                {
                    Color = System.Windows.Media.Colors.Black,
                    BlurRadius = 25,
                    ShadowDepth = 8,
                    Opacity = 0.35
                },
                Cursor = System.Windows.Input.Cursors.Hand
            };

            Grid grid = new Grid();
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(64) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            iconLabel = new TextBlock
            {
                Text = "🔒",
                FontSize = 20,
                Foreground = System.Windows.Media.Brushes.White,
                VerticalAlignment = System.Windows.VerticalAlignment.Center,
                HorizontalAlignment = System.Windows.HorizontalAlignment.Center
            };
            Grid.SetColumn(iconLabel, 0);
            grid.Children.Add(iconLabel);

            txtLabel = new TextBlock
            {
                Text = "Tahtayı Kilitle",
                FontSize = 16,
                FontWeight = FontWeights.Bold,
                Foreground = System.Windows.Media.Brushes.White,
                VerticalAlignment = System.Windows.VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 20, 0)
            };
            Grid.SetColumn(txtLabel, 1);
            grid.Children.Add(txtLabel);

            mainBorder.Child = grid;
            this.Content = mainBorder;

            mainBorder.MouseEnter += (s, e) => {
                if (!isDragging) mainBorder.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(59, 130, 246));
            };
            mainBorder.MouseLeave += (s, e) => {
                if (!isDragging) mainBorder.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(37, 99, 235));
            };

            mainBorder.MouseLeftButtonDown += Btn_MouseDown;
            mainBorder.MouseMove += Btn_MouseMove;
            mainBorder.MouseLeftButtonUp += Btn_MouseUp;

            collapseTimer = new System.Windows.Threading.DispatcherTimer { Interval = TimeSpan.FromSeconds(5) };
            collapseTimer.Tick += (s, e) => Collapse();
            collapseTimer.Start();
        }

        // ==========================================
        // YENİ: KUSURSUZ SÜRÜKLEME VE KİLİTLEME DİNAMİKLERİ
        // ==========================================
        private void Btn_MouseDown(object sender, MouseButtonEventArgs e)
        {
            if (e.ChangedButton == MouseButton.Left)
            {
                isDragging = true;
                mainBorder.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(30, 64, 175));

                // 1. KRİTİK ADIM: Manuel kontrole geçmeden önce WPF'in eski animasyon kilitlerini TEMİZLE!
                this.BeginAnimation(Window.LeftProperty, null);
                this.BeginAnimation(Window.TopProperty, null);

                // 2. Global fare konumunu ve pencerenin o anki konumunu kaydet
                dragStartMousePos = WinForms.Cursor.Position;
                dragStartWindowLeft = this.Left;
                dragStartWindowTop = this.Top;

                mainBorder.CaptureMouse();
            }
        }

        private void Btn_MouseMove(object sender, System.Windows.Input.MouseEventArgs e)
        {
            if (isDragging)
            {
                // WPF DragMove() kullanmıyoruz! Windows Snap (Yerleştirme) ekranının çıkmasını kökten engeller.
                var currentMousePos = WinForms.Cursor.Position;
                double deltaX = currentMousePos.X - dragStartMousePos.X;
                double deltaY = currentMousePos.Y - dragStartMousePos.Y;

                this.Left = dragStartWindowLeft + deltaX;
                this.Top = dragStartWindowTop + deltaY;
            }
        }

        private void Btn_MouseUp(object sender, MouseButtonEventArgs e)
        {
            if (!isDragging) return;
            isDragging = false;

            mainBorder.ReleaseMouseCapture();
            mainBorder.Background = new SolidColorBrush(System.Windows.Media.Color.FromRgb(37, 99, 235));

            var currentMousePos = WinForms.Cursor.Position;
            double deltaX = Math.Abs(currentMousePos.X - dragStartMousePos.X);
            double deltaY = Math.Abs(currentMousePos.Y - dragStartMousePos.Y);

            // Bırakılan yere en yakın kenara yumuşakça yapış
            SnapToEdge();

            // Sürüklenmediyse tıklanmıştır
            if (deltaX < 5 && deltaY < 5)
            {
                if (!isExpanded) Expand();
                else OnLockRequested?.Invoke();
            }
            else
            {
                // Sürüklendiyse süreyi baştan başlat
                if (isExpanded)
                {
                    collapseTimer.Stop();
                    collapseTimer.Start();
                }
            }
        }

        // ==========================================
        // 60FPS PÜRÜZSÜZ (SMOOTH) ANİMASYONLAR
        // ==========================================
        private void Expand()
        {
            if (isExpanded) return;
            isExpanded = true;

            DoubleAnimation widthAnim = new DoubleAnimation(expandedWidth, TimeSpan.FromMilliseconds(300)) { EasingFunction = new CubicEase { EasingMode = EasingMode.EaseOut } };
            DoubleAnimation opacityAnim = new DoubleAnimation(1.0, TimeSpan.FromMilliseconds(200));

            txtLabel.BeginAnimation(UIElement.OpacityProperty, opacityAnim);
            mainBorder.BeginAnimation(FrameworkElement.WidthProperty, widthAnim);

            UpdateTargetSnapLocation(expandedWidth);
            collapseTimer.Stop();
            collapseTimer.Start();
        }

        private void Collapse()
        {
            if (!isExpanded || isDragging) return;
            isExpanded = false;

            DoubleAnimation widthAnim = new DoubleAnimation(collapsedWidth, TimeSpan.FromMilliseconds(300)) { EasingFunction = new CubicEase { EasingMode = EasingMode.EaseInOut } };
            DoubleAnimation opacityAnim = new DoubleAnimation(0.0, TimeSpan.FromMilliseconds(150));

            txtLabel.BeginAnimation(UIElement.OpacityProperty, opacityAnim);
            mainBorder.BeginAnimation(FrameworkElement.WidthProperty, widthAnim);

            UpdateTargetSnapLocation(collapsedWidth);
            collapseTimer.Stop();
        }

        // ==========================================
        // AKILLI KENAR YAPIŞTIRMA (Çoklu Monitör Korumalı)
        // ==========================================
        private void SnapToEdge()
        {
            UpdateTargetSnapLocation(isExpanded ? expandedWidth : collapsedWidth);
        }

        private void UpdateTargetSnapLocation(double targetWidgetWidth)
        {
            // O an pencere hangi ekrandaysa o ekranın sınırlarını al (Ekran dışına kaybolmasını önler)
            var hwnd = new WindowInteropHelper(this).Handle;
            var screen = WinForms.Screen.FromHandle(hwnd).WorkingArea;

            double centerX = this.Left + (targetWidgetWidth / 2);

            // X Ekseni (Sağa veya Sola yapış)
            double targetX = (centerX > screen.Left + (screen.Width / 2))
                ? screen.Right - targetWidgetWidth - 20
                : screen.Left - 10;

            // Y Ekseni (Görev çubuğu veya üst sınırdan taşmasını önle)
            double targetY = Math.Max(screen.Top - 10, Math.Min(this.Top, screen.Bottom - widgetHeight - 20));

            DoubleAnimation moveX = new DoubleAnimation(targetX, TimeSpan.FromMilliseconds(250)) { EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut } };
            DoubleAnimation moveY = new DoubleAnimation(targetY, TimeSpan.FromMilliseconds(250)) { EasingFunction = new QuadraticEase { EasingMode = EasingMode.EaseOut } };

            this.BeginAnimation(Window.LeftProperty, moveX);
            this.BeginAnimation(Window.TopProperty, moveY);

            // Windows'un TopMost'u unutmaması için zorla yenile
            this.Topmost = false;
            this.Topmost = true;
        }

        // Alt+Tab'dan gizleme ve sistem pencerelerinin altında kalmama kancası
        protected override void OnSourceInitialized(EventArgs e)
        {
            base.OnSourceInitialized(e);
            var hwnd = new WindowInteropHelper(this).Handle;
            int exStyle = (int)GetWindowLong(hwnd, GWL_EXSTYLE);

            // WS_EX_TOOLWINDOW: Alt+Tab menüsünde çıkmasını engeller
            // WS_EX_TOPMOST: Uygulamanın her koşulda en üstte renderlanmasını işletim sistemine dayatır
            SetWindowLong(hwnd, GWL_EXSTYLE, (IntPtr)(exStyle | WS_EX_TOOLWINDOW | 0x00000008));
        }

        private const int GWL_EXSTYLE = -20;
        private const int WS_EX_TOOLWINDOW = 0x00000080;
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern IntPtr SetWindowLong(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    }
}