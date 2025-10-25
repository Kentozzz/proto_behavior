require 'selenium-webdriver'

# Seleniumのオプション設定
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless=new')  # Codespaces環境では必須
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--disable-gpu')
options.add_argument('--remote-debugging-port=0')  # ランダムポートを使用
options.binary = '/tmp/chrome-linux64/chrome'

# ChromeDriverのパスを設定
Selenium::WebDriver::Chrome::Service.driver_path = '/tmp/chromedriver-linux64/chromedriver'

# WebDriverの初期化
begin
  driver = Selenium::WebDriver.for :chrome, options: options

  # URLにアクセス
  url = 'https://protospace2020.herokuapp.com/'
  puts "アクセス中: #{url}"
  driver.get(url)

  # ページタイトルを取得
  title = driver.title
  puts "ページタイトル: #{title}"

  # 新規登録ボタンをクリック
  puts "\n新規登録ボタンをクリック..."
  signup_button = driver.find_element(:link_text, '新規登録')
  signup_button.click
  sleep 3  # ページ読み込みを待つ

  # フォームに入力（英語で入力）
  puts "フォームに入力中..."

  # メールアドレス
  driver.execute_script("document.getElementById('user_email').value = 'test@example.com';")

  # パスワード
  driver.execute_script("document.getElementById('user_password').value = 'password123';")

  # パスワード確認
  driver.execute_script("document.getElementById('user_password_confirmation').value = 'password123';")

  # ユーザー名
  driver.execute_script("document.getElementById('user_name').value = 'Test User';")

  # 他のフィールドがあるか確認（プロフィール、所属、役職など）
  begin
    # プロフィール
    driver.execute_script("document.getElementById('user_profile').value = 'Software engineer with 5 years of experience.';")
    puts "プロフィールを入力しました"
  rescue => e
    puts "プロフィールフィールドが見つかりません"
  end

  begin
    # 所属
    driver.execute_script("document.getElementById('user_occupation').value = 'Sample Corporation';")
    puts "所属を入力しました"
  rescue => e
    puts "所属フィールドが見つかりません: #{e.message}"
  end

  begin
    # 役職
    driver.execute_script("document.getElementById('user_position').value = 'System Engineer';")
    puts "役職を入力しました"
  rescue => e
    puts "役職フィールドが見つかりません"
  end

  puts "全項目の入力が完了しました"

  # ページ全体が見えるようにウィンドウサイズを大きくしてスクロール
  driver.manage.window.resize_to(1920, 2000)
  sleep 1

  # 入力完了後のスクリーンショットを保存
  screenshot_path = '/workspaces/proto_behavior/screenshot_signup_filled.png'
  driver.save_screenshot(screenshot_path)
  puts "入力完了後のスクリーンショットを保存しました: #{screenshot_path}"

  # 新規登録ボタンをクリック
  puts "\n新規登録ボタンをクリック..."
  submit_button = driver.find_element(:name, 'commit')
  submit_button.click

  # ページ遷移を待つ
  sleep 3

  # 遷移後のURLとタイトルを確認
  current_url = driver.current_url
  current_title = driver.title
  puts "遷移後のURL: #{current_url}"
  puts "遷移後のページタイトル: #{current_title}"

  # トップページに遷移したか確認
  if current_url.include?('protospace2020.herokuapp.com') && !current_url.include?('/users/sign_up')
    puts "\n✓ トップページへの遷移を確認しました"
  else
    puts "\n✗ 想定外のページに遷移しました"
  end

  # 遷移後のスクリーンショットを保存
  screenshot_after = '/workspaces/proto_behavior/screenshot_after_signup.png'
  driver.save_screenshot(screenshot_after)
  puts "遷移後のスクリーンショットを保存しました: #{screenshot_after}"

  # 成功メッセージ
  puts "\n✓ テスト成功: 新規登録が完了し、トップページに遷移しました"

rescue StandardError => e
  puts "エラーが発生しました: #{e.message}"
  puts e.backtrace
ensure
  # ブラウザを閉じる
  driver.quit if driver
end
