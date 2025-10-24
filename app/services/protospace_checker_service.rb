class ProtospaceCheckerService
  attr_reader :check_session, :driver, :base_url

  def initialize(check_session)
    @check_session = check_session
    @base_url = check_session.target_url.gsub(/\/+$/, '')
    setup_driver
  end

  def setup_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument("--user-data-dir=/tmp/chrome-test-#{Time.now.to_i}-#{rand(10000)}")
    options.binary = '/tmp/chrome-linux64/chrome'

    Selenium::WebDriver::Chrome::Service.driver_path = '/tmp/chromedriver-linux64/chromedriver'
    @driver = Selenium::WebDriver.for :chrome, options: options
    @driver.manage.window.resize_to(1920, 1080)
  end

  def run_check_1_013
    begin
      # まず新規ユーザーを作成
      test_email = "login-test-#{Time.now.to_i}@example.com"
      test_password = "password123"

      # 新規登録ページに移動
      driver.get("#{base_url}/users/sign_up")
      sleep 2

      # フォームに入力
      driver.execute_script("document.getElementById('user_email').value = '#{test_email}';")
      driver.execute_script("document.getElementById('user_password').value = '#{test_password}';")
      driver.execute_script("document.getElementById('user_password_confirmation').value = '#{test_password}';")
      driver.execute_script("document.getElementById('user_name').value = 'Login Test User';")
      driver.execute_script("document.getElementById('user_profile').value = 'Login Test Profile';")
      driver.execute_script("document.getElementById('user_occupation').value = 'Login Test Company';")
      driver.execute_script("document.getElementById('user_position').value = 'Login Test Position';")

      # 登録ボタンをクリック
      driver.find_element(:name, 'commit').click
      sleep 3

      # ログアウト
      driver.get(base_url)
      sleep 1
      logout_link = driver.find_element(:link_text, 'ログアウト')
      logout_link.click
      sleep 2

      # ログインを試行
      driver.get("#{base_url}/users/sign_in")
      sleep 1
      driver.execute_script("document.getElementById('user_email').value = '#{test_email}';")
      driver.execute_script("document.getElementById('user_password').value = '#{test_password}';")
      driver.find_element(:name, 'commit').click
      sleep 3

      # トップページに遷移したか確認
      current_url = driver.current_url
      is_top_page = (current_url == base_url || current_url == "#{base_url}/")

      if is_top_page
        add_result("1-013", "必要な情報を入力すると、ログインができること", "PASS", "")
      else
        add_result("1-013", "必要な情報を入力すると、ログインができること", "FAIL", "正しい情報を入力してもログインできません。現在のURL: #{current_url}")
      end

    rescue => e
      add_result("1-013", "必要な情報を入力すると、ログインができること", "ERROR", e.message)
    ensure
      cleanup
    end

    # セッション更新
    check_session.update!(status: 'completed', completed_at: Time.current)
  end

  private

  def add_result(check_number, description, status, note)
    CheckResult.create!(
      check_session: check_session,
      section_number: 1,
      check_number: check_number,
      description: description,
      status: status,
      note: note
    )
  end

  def cleanup
    @driver.quit if @driver
  rescue => e
    Rails.logger.error "Driver cleanup error: #{e.message}"
  end
end
