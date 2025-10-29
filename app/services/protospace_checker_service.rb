class ProtospaceCheckerService
  attr_reader :driver, :base_url, :results, :logs, :registered_users, :posted_prototype, :screenshots, :failure_screenshots

  def initialize(target_url, session_id: nil, sessions_store: nil, &log_callback)
    @base_url = target_url.gsub(/\/+$/, '')
    @results = []
    @logs = []
    @registered_users = []
    @posted_prototype = {}
    @screenshots = []
    @failure_screenshots = []
    @log_callback = log_callback
    @session_id = session_id
    @sessions_store = sessions_store
    @screenshot_timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    setup_driver
  end

  def run_all_checks
    add_log("全チェックを開始します", :info)

    # バリデーションチェック（1-001 ~ 1-010）
    check_cancelled
    run_validation_checks

    # 1-011: ユーザー新規登録
    check_cancelled
    add_log("ブラウザを起動中...", :progress)
    setup_driver
    run_check_1_011(cleanup_logs: false)

    # 1-012: ログインフォーム空欄チェック
    check_cancelled
    add_log("ブラウザを再起動中...", :progress)
    setup_driver
    run_check_1_012(cleanup_logs: false)

    # 1-013〜1-017: 同じブラウザセッションで実行
    check_cancelled
    add_log("ブラウザを再起動中...", :progress)
    setup_driver
    run_check_1_013(cleanup_logs: false)
    run_check_1_014(cleanup_logs: false)
    run_check_1_015(cleanup_logs: false)
    run_check_1_016(cleanup_logs: false)
    run_check_1_017(cleanup_logs: false)

    # 1-018: パスワード一致チェック
    check_cancelled
    add_log("ブラウザを再起動中...", :progress)
    setup_driver
    run_check_1_018(cleanup_logs: false)

    # セクション1完了：ユーザー機能関連のスクリーンショット撮影
    check_cancelled
    capture_section_1_screenshots

    # 2-001〜2-006: 投稿ページ遷移とバリデーションチェック（同じセッション）
    check_cancelled
    add_log("ブラウザを再起動中...", :progress)
    setup_driver
    run_check_2_001(cleanup_logs: false)
    run_prototype_validation_checks

    # 2-007〜2-009: 正常投稿とトップページ表示確認
    check_cancelled
    add_log("ブラウザを再起動中...", :progress)
    setup_driver
    run_check_2_007(cleanup_logs: false)

    # セクション2完了：投稿機能関連のスクリーンショット撮影
    check_cancelled
    capture_section_2_screenshots

    # 3-001〜3-003: プロトタイプ一覧表示機能（同じセッション）
    check_cancelled
    run_check_3_001(cleanup_logs: false)
    run_check_3_002_and_3_003(cleanup_logs: false)

    # 4-001〜4-003: プロトタイプ詳細表示機能（同じセッション）
    check_cancelled
    run_check_4_001_4_002_4_003(cleanup_logs: false)

    # セクション4完了：プロトタイプ詳細ページのスクリーンショット撮影
    check_cancelled
    capture_section_4_screenshots

    # 5-001〜5-005: プロトタイプ編集機能（同じセッション）
    check_cancelled
    run_check_5_001_to_5_005(cleanup_logs: false)

    # セクション5完了：プロトタイプ編集ページのスクリーンショット撮影
    check_cancelled
    capture_section_5_screenshots

    # 6-001〜6-002: プロトタイプ削除機能（同じセッション）
    check_cancelled
    run_check_6_001_6_002(cleanup_logs: false)

    # 7-001〜7-004 + チェック番号4: コメント機能（同じセッション）
    check_cancelled
    run_check_7_001_to_7_004(cleanup_logs: false)

    # 8-001 + チェック番号5: ユーザー詳細機能（同じセッション）
    check_cancelled
    run_check_8_001_and_check_5(cleanup_logs: false)

    # セクション8完了：ユーザー詳細ページのスクリーンショット撮影
    check_cancelled
    capture_section_8_screenshots

    # 9-001, 9-002 + チェック番号6: その他機能（同じセッション）
    check_cancelled
    run_check_9_001_9_002_and_check_6(cleanup_logs: false)

    # 最後にクリーンアップとログ整理
    cleanup
    add_log("全チェック完了", :info)
    @logs.reject! { |log| log[:type] == :progress }

    { results: results, logs: logs, registered_users: registered_users, screenshots: screenshots, failure_screenshots: failure_screenshots }
  end

  def run_validation_checks
    # 基本データ
    base_data = {
      email: "validation-test-#{Time.now.to_i}@example.com",
      password: "aaa111",
      password_confirmation: "aaa111",
      name: "テストユーザー",
      profile: "テストプロフィール",
      occupation: "テスト会社",
      position: "テスト役職"
    }

    # 1-001: メールアドレス必須
    check_required_field("1-001", "メールアドレスが必須であること", base_data, :email, "")

    # 1-002: メールアドレス一意性
    check_email_uniqueness("1-002", base_data)

    # 1-003: メールアドレスに@を含む
    check_email_format("1-003", base_data)

    # 1-004: パスワード必須
    check_required_field("1-004", "パスワードが必須であること", base_data, :password, "")

    # 1-005: パスワード6文字以上
    check_password_length("1-005", base_data)

    # 1-006: パスワード確認2回入力
    check_password_confirmation("1-006", base_data)

    # 1-007: ユーザー名必須
    check_required_field("1-007", "ユーザー名が必須であること", base_data, :name, "")

    # 1-008: プロフィール必須
    check_required_field("1-008", "プロフィールが必須であること", base_data, :profile, "")

    # 1-009: 所属必須
    check_required_field("1-009", "所属が必須であること", base_data, :occupation, "")

    # 1-010: 役職必須
    check_required_field("1-010", "役職が必須であること", base_data, :position, "")
  end

  def check_required_field(check_number, description, base_data, field, invalid_value)
    begin
      add_log("　 #{check_number}: #{description}", :check_start)
      add_log("#{field}を空にして登録を試行中...", :progress)

      test_data = base_data.dup
      test_data[field] = invalid_value

      driver.get("#{base_url}/users/sign_up")
      fill_signup_form(test_data)
      driver.find_element(:name, 'commit').click
      sleep 2

      current_url = driver.current_url
      is_signup_page = current_url.include?('/users/sign_up') || current_url.include?('/users')

      if is_signup_page && !current_url.end_with?('/')
        add_log("✓ #{check_number}: #{description}", :success)
        add_result(check_number, description, "PASS", "")
      else
        add_log("✗ #{check_number}: #{description} (失敗)", :fail)
        add_result(check_number, description, "FAIL", "#{field}が空でも登録できてしまいます")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result(check_number, description, "ERROR", e.message)
    end
  end

  def check_email_uniqueness(check_number, base_data)
    begin
      description = "メールアドレスは一意性であること"
      add_log("　 #{check_number}: #{description}", :check_start)

      # まず1件登録
      add_log("ログアウト状態: テストユーザーを登録中...", :progress)
      unique_email = "unique-test-#{Time.now.to_i}@example.com"
      test_data = base_data.dup
      test_data[:email] = unique_email

      driver.get("#{base_url}/users/sign_up")
      sleep 1
      fill_signup_form(test_data)
      driver.find_element(:name, 'commit').click
      sleep 2

      # 登録したユーザー情報を保存
      @registered_users << {
        email: unique_email,
        password: test_data[:password],
        name: test_data[:name],
        profile: test_data[:profile],
        occupation: test_data[:occupation],
        position: test_data[:position]
      }

      # セッションストアに登録ユーザーを保存
      if @sessions_store && @session_id && @sessions_store[@session_id]
        @sessions_store[@session_id][:registered_users] = @registered_users
      end

      # ログアウト
      add_log("ログアウト中...", :progress)
      driver.get(base_url)
      sleep 1
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # ログアウトリンクがない場合はスキップ
      end

      # 同じメールアドレスで再登録を試行
      add_log("ログアウト状態: 同じメールアドレスで再登録を試行中...", :progress)
      driver.get("#{base_url}/users/sign_up")
      sleep 1
      fill_signup_form(test_data)
      driver.find_element(:name, 'commit').click
      sleep 2

      current_url = driver.current_url
      is_signup_page = current_url.include?('/users/sign_up') || current_url.include?('/users')

      if is_signup_page && !current_url.end_with?('/')
        add_log("✓ #{check_number}: #{description}", :success)
        add_result(check_number, description, "PASS", "")
      else
        add_log("✗ #{check_number}: #{description} (失敗)", :fail)
        add_result(check_number, description, "FAIL", "同じメールアドレスで登録できてしまいます")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result(check_number, description, "ERROR", e.message)
    end
  end

  def check_email_format(check_number, base_data)
    begin
      description = "メールアドレスは@を含む必要があること"
      add_log("　 #{check_number}: #{description}", :check_start)
      add_log("ログアウト状態: @を含まないメールアドレスで登録を試行中...", :progress)

      test_data = base_data.dup
      test_data[:email] = "invalidemail.com"

      driver.get("#{base_url}/users/sign_up")
      fill_signup_form(test_data)
      driver.find_element(:name, 'commit').click
      sleep 2

      current_url = driver.current_url
      is_signup_page = current_url.include?('/users/sign_up') || current_url.include?('/users')

      if is_signup_page && !current_url.end_with?('/')
        add_log("✓ #{check_number}: #{description}", :success)
        add_result(check_number, description, "PASS", "")
      else
        add_log("✗ #{check_number}: #{description} (失敗)", :fail)
        add_result(check_number, description, "FAIL", "@を含まないメールアドレスで登録できてしまいます")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result(check_number, description, "ERROR", e.message)
    end
  end

  def check_password_length(check_number, base_data)
    begin
      description = "パスワードは6文字以上であること"
      add_log("　 #{check_number}: #{description}", :check_start)
      add_log("ログアウト状態: 5文字のパスワードで登録を試行中...", :progress)

      test_data = base_data.dup
      test_data[:password] = "12345"
      test_data[:password_confirmation] = "12345"

      driver.get("#{base_url}/users/sign_up")
      fill_signup_form(test_data)
      driver.find_element(:name, 'commit').click
      sleep 2

      current_url = driver.current_url
      is_signup_page = current_url.include?('/users/sign_up') || current_url.include?('/users')

      if is_signup_page && !current_url.end_with?('/')
        add_log("✓ #{check_number}: #{description}", :success)
        add_result(check_number, description, "PASS", "")
      else
        add_log("✗ #{check_number}: #{description} (失敗)", :fail)
        add_result(check_number, description, "FAIL", "6文字未満のパスワードで登録できてしまいます")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result(check_number, description, "ERROR", e.message)
    end
  end

  def check_password_confirmation(check_number, base_data)
    begin
      description = "パスワードは確認用を含めて2回入力すること"
      add_log("　 #{check_number}: #{description}", :check_start)
      add_log("ログアウト状態: パスワード確認を空にして登録を試行中...", :progress)

      test_data = base_data.dup
      test_data[:password_confirmation] = ""

      driver.get("#{base_url}/users/sign_up")
      fill_signup_form(test_data)
      driver.find_element(:name, 'commit').click
      sleep 2

      current_url = driver.current_url
      is_signup_page = current_url.include?('/users/sign_up') || current_url.include?('/users')

      if is_signup_page && !current_url.end_with?('/')
        add_log("✓ #{check_number}: #{description}", :success)
        add_result(check_number, description, "PASS", "")
      else
        add_log("✗ #{check_number}: #{description} (失敗)", :fail)
        add_result(check_number, description, "FAIL", "パスワード確認なしで登録できてしまいます")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result(check_number, description, "ERROR", e.message)
    end
  end

  def fill_signup_form(data)
    # リトライ付きで各フィールドに値を設定
    set_element_value_with_retry('user_email', data[:email])
    set_element_value_with_retry('user_password', data[:password])
    set_element_value_with_retry('user_password_confirmation', data[:password_confirmation])
    set_element_value_with_retry('user_name', data[:name])
    set_element_value_with_retry('user_profile', data[:profile])
    set_element_value_with_retry('user_occupation', data[:occupation])
    set_element_value_with_retry('user_position', data[:position])
  end

  def setup_driver
    ensure_chrome_environment
    cleanup if @driver

    # 古いChromeプロセスをクリーンアップ（前回のテストが不完全に終了した場合に備えて）
    system("pkill -f 'chrome.*--headless' > /dev/null 2>&1")
    sleep 1

    # セッションごとに独立したuser-data-dirを使用（Cookieが引き継がれないように）
    timestamp = Time.now.to_i
    random_id = rand(10000)
    user_data_dir = "/tmp/user-data-#{timestamp}-#{random_id}"

    # ランダムなリモートデバッギングポートを使用（競合を避ける）
    debug_port = 9222 + rand(1000)

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--disable-software-rasterizer')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-web-security')
    options.add_argument('--disable-setuid-sandbox')
    options.add_argument("--remote-debugging-port=#{debug_port}")
    options.add_argument('--window-size=1280,720')
    options.add_argument("--user-data-dir=#{user_data_dir}")
    options.add_argument("--data-path=/tmp/data-path-#{timestamp}")
    options.add_argument("--disk-cache-dir=/tmp/cache-dir-#{timestamp}")
    options.add_argument('--remote-debugging-address=0.0.0.0')
    options.add_argument('--single-process')
    options.add_argument('--disable-renderer-backgrounding')
    options.binary = '/tmp/chrome-linux64/chrome'

    Selenium::WebDriver::Chrome::Service.driver_path = '/tmp/chromedriver-linux64/chromedriver'

    begin
      @driver = Selenium::WebDriver.for :chrome, options: options
      @driver.manage.window.resize_to(1280, 720)
      @driver.manage.timeouts.implicit_wait = 10
    rescue => e
      Rails.logger.error "ドライバー起動エラー: #{e.message}"
      # 古いChromeプロセスをクリーンアップして再試行
      system("pkill -f chrome")
      sleep 2
      @driver = Selenium::WebDriver.for :chrome, options: options
      @driver.manage.window.resize_to(1280, 720)
      @driver.manage.timeouts.implicit_wait = 10
    end
  end

  def run_check_1_011(cleanup_logs: true)
    begin
      add_log("　 1-011: 必須項目に適切な値を入力すると、ユーザーの新規登録ができること", :check_start)

      # テストユーザーを作成
      test_email = "signup-test-#{Time.now.to_i}@example.com"
      test_password = "aaa111"

      # 新規登録ページに移動
      add_log("ログアウト状態: 新規登録ページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_up")
      sleep 2

      # フォームに入力
      add_log("ログアウト状態: 必須項目を入力中...", :progress)
      set_element_value_with_retry('user_email', test_email)
      set_element_value_with_retry('user_password', test_password)
      set_element_value_with_retry('user_password_confirmation', test_password)
      set_element_value_with_retry('user_name', 'テストユーザー')
      set_element_value_with_retry('user_profile', 'テストプロフィール')
      set_element_value_with_retry('user_occupation', 'テスト会社')
      set_element_value_with_retry('user_position', 'テスト役職')

      # 登録ボタンをクリック
      add_log("ログアウト状態: ユーザー登録を実行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 3

      # トップページに遷移したか確認
      add_log("ログイン状態: 登録結果を確認中...", :progress)
      current_url = driver.current_url
      is_top_page = (current_url == base_url || current_url == "#{base_url}/")

      if is_top_page
        add_log("✓ 1-011: 必須項目に適切な値を入力すると、ユーザーの新規登録ができること", :success)
        add_result("1-011", "必須項目に適切な値を入力すると、ユーザーの新規登録ができること", "PASS", "")

        # 登録したユーザー情報を保存
        @registered_users << {
          email: test_email,
          password: test_password,
          name: "テストユーザー",
          profile: "テストプロフィール",
          occupation: "テスト会社",
          position: "テスト役職"
        }

        # セッションストアに登録ユーザーを保存
        if @sessions_store && @session_id && @sessions_store[@session_id]
          @sessions_store[@session_id][:registered_users] = @registered_users
        end
      else
        add_log("✗ 1-011: 必須項目に適切な値を入力すると、ユーザーの新規登録ができること (失敗)", :fail)
        add_result("1-011", "必須項目に適切な値を入力すると、ユーザーの新規登録ができること", "FAIL", "登録後に正しいページに遷移しません。現在のURL: #{current_url}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("1-011", "必須項目に適切な値を入力すると、ユーザーの新規登録ができること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        # 完了時にprogressログを削除
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_check_1_012(cleanup_logs: true)
    begin
      add_log("　 1-012: フォームに適切な値が入力されていない状態では、ログインできず、そのページに留まること", :check_start)

      # ログインページに移動
      add_log("ログアウト状態: ログインページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_in")

      # フォームに何も入力せずにログインボタンをクリック
      add_log("ログアウト状態: 空欄のままログインを試行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 2

      # ログインページに留まっているか確認（トップページに遷移していないことを確認）
      add_log("ログアウト状態: ログイン結果を確認中...", :progress)
      current_url = driver.current_url
      is_top_page = (current_url == base_url || current_url == "#{base_url}/")

      if !is_top_page
        add_log("✓ 1-012: フォームに適切な値が入力されていない状態では、ログインできず、そのページに留まること", :success)
        add_result("1-012", "フォームに適切な値が入力されていない状態では、ログインできず、そのページに留まること", "PASS", "")
      else
        add_log("✗ 1-012: フォームに適切な値が入力されていない状態では、ログインできず、そのページに留まること (失敗)", :fail)
        add_result("1-012", "フォームに適切な値が入力されていない状態では、ログインできず、そのページに留まること", "FAIL", "空欄でログインできてしまいます。現在のURL: #{current_url}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("1-012", "フォームに適切な値が入力されていない状態では、ログインできず、そのページに留まること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        # 完了時にprogressログを削除
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_check_1_013(cleanup_logs: true)
    begin
      add_log("　 1-013: 必要な情報を入力すると、ログインができること", :check_start)
      add_log("ログアウト状態: ログイン準備中...", :progress)

      # 既存ユーザーを使用
      if @registered_users.empty?
        add_log("✗ 1-013: 必要な情報を入力すると、ログインができること (失敗)", :fail)
        add_result("1-013", "必要な情報を入力すると、ログインができること", "ERROR", "登録済みユーザーが見つかりません")
        return { results: results, logs: logs }
      end

      test_user = @registered_users[1] || @registered_users.first  # 1-011で登録したユーザーを使用
      test_email = test_user[:email]
      test_password = test_user[:password]

      # ログインページに移動
      add_log("ログインページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      # ログイン情報を入力
      add_log("ログイン情報を入力中...", :progress)
      set_element_value_with_retry('user_email', test_email)
      set_element_value_with_retry('user_password', test_password)

      # ログインボタンをクリック
      add_log("ログイン実行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 3

      # トップページに遷移したか確認
      add_log("ログイン結果を確認中...", :progress)
      current_url = driver.current_url
      is_top_page = (current_url == base_url || current_url == "#{base_url}/")

      if is_top_page
        add_log("✓ 1-013: 必要な情報を入力すると、ログインができること", :success)
        add_result("1-013", "必要な情報を入力すると、ログインができること", "PASS", "")
      else
        add_log("✗ 1-013: 必要な情報を入力すると、ログインができること (失敗)", :fail)
        add_result("1-013", "必要な情報を入力すると、ログインができること", "FAIL", "正しい情報を入力してもログインできません。現在のURL: #{current_url}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("1-013", "必要な情報を入力すると、ログインができること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        # 完了時にprogressログを削除
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_check_1_014(cleanup_logs: true)
    begin
      add_log("　 1-014: トップページから、ログアウトができること", :check_start)

      # 1-013でログイン済みなので、トップページでログアウトリンクを探してクリック
      add_log("ログイン状態: ログアウトリンクを探しています...", :progress)
      driver.get(base_url)

      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        add_log("ログイン状態: ログアウト実行中...", :progress)
        logout_link.click
        sleep 2

        # ログアウトできたか確認（ログアウト後はログインページやトップページに遷移）
        add_log("ログアウト状態: ログアウト結果を確認中...", :progress)
        current_url = driver.current_url

        # ログアウトリンクがなくなっていることを確認
        logout_exists = false
        begin
          driver.find_element(:link_text, 'ログアウト')
          logout_exists = true
        rescue
          logout_exists = false
        end

        if !logout_exists
          add_log("✓ 1-014: トップページから、ログアウトができること", :success)
          add_result("1-014", "トップページから、ログアウトができること", "PASS", "")
        else
          add_log("✗ 1-014: トップページから、ログアウトができること (失敗)", :fail)
          add_result("1-014", "トップページから、ログアウトができること", "FAIL", "ログアウト後もログアウトリンクが表示されています")
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        add_log("✗ 1-014: トップページから、ログアウトができること (失敗)", :fail)
        add_result("1-014", "トップページから、ログアウトができること", "FAIL", "ログアウトリンクが見つかりません")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("1-014", "トップページから、ログアウトができること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        # 完了時にprogressログを削除
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_check_1_015(cleanup_logs: true)
    begin
      add_log("　 1-015: ログイン状態では、ヘッダーに「ログアウト」「New Proto」のリンクが存在すること", :check_start)

      # 既存ユーザーでログイン
      if @registered_users.empty?
        add_log("✗ 1-015: ログイン状態では、ヘッダーに「ログアウト」「New Proto」のリンクが存在すること (失敗)", :fail)
        add_result("1-015", "ログイン状態では、ヘッダーに「ログアウト」「New Proto」のリンクが存在すること", "ERROR", "登録済みユーザーが見つかりません")
        return { results: results, logs: logs }
      end

      test_user = @registered_users.first
      test_email = test_user[:email]
      test_password = test_user[:password]

      # ログインページに移動
      add_log("ログアウト状態: ログインページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      # ログイン情報を入力
      add_log("ログアウト状態: ログイン情報を入力中...", :progress)
      set_element_value_with_retry('user_email', test_email)
      set_element_value_with_retry('user_password', test_password)

      # ログインボタンをクリック
      add_log("ログアウト状態: ログイン実行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 3

      # トップページでヘッダーリンクを確認
      add_log("ログイン状態: ヘッダーリンクを確認中...", :progress)
      driver.get(base_url)

      logout_exists = false
      new_proto_exists = false

      begin
        driver.find_element(:link_text, 'ログアウト')
        logout_exists = true
      rescue
        logout_exists = false
      end

      begin
        driver.find_element(:link_text, 'New Proto')
        new_proto_exists = true
      rescue
        new_proto_exists = false
      end

      if logout_exists && new_proto_exists
        add_log("✓ 1-015: ログイン状態では、ヘッダーに「ログアウト」「New Proto」のリンクが存在すること", :success)
        add_result("1-015", "ログイン状態では、ヘッダーに「ログアウト」「New Proto」のリンクが存在すること", "PASS", "")
      else
        missing_links = []
        missing_links << "ログアウト" unless logout_exists
        missing_links << "New Proto" unless new_proto_exists
        add_log("✗ 1-015: ログイン状態では、ヘッダーに「ログアウト」「New Proto」のリンクが存在すること (失敗)", :fail)
        add_result("1-015", "ログイン状態では、ヘッダーに「ログアウト」「New Proto」のリンクが存在すること", "FAIL", "以下のリンクが見つかりません: #{missing_links.join(', ')}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("1-015", "ログイン状態では、ヘッダーに「ログアウト」「New Proto」のリンクが存在すること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        # 完了時にprogressログを削除
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_check_1_016(cleanup_logs: true)
    begin
      add_log("　 1-016: ログイン状態では、トップページに「こんにちは、〇〇さん」とユーザー名が表示されていること", :check_start)

      # 既存ユーザーの情報を取得（1-015でログイン済み）
      if @registered_users.empty?
        add_log("✗ 1-016: ログイン状態では、トップページに「こんにちは、〇〇さん」とユーザー名が表示されていること (失敗)", :fail)
        add_result("1-016", "ログイン状態では、トップページに「こんにちは、〇〇さん」とユーザー名が表示されていること", "ERROR", "登録済みユーザーが見つかりません")
        return { results: results, logs: logs }
      end

      test_user = @registered_users.first  # 1-015でログインしたユーザー
      test_name = test_user[:name]  # 登録されたユーザーの名前を使用

      # トップページでユーザー名表示を確認（既にログイン済み）
      add_log("ログイン状態: ユーザー名表示を確認中...", :progress)
      driver.get(base_url)

      page_text = driver.find_element(:tag_name, 'body').text
      greeting_exists = page_text.include?("こんにちは") && page_text.include?(test_name)

      if greeting_exists
        add_log("✓ 1-016: ログイン状態では、トップページに「こんにちは、〇〇さん」とユーザー名が表示されていること", :success)
        add_result("1-016", "ログイン状態では、トップページに「こんにちは、〇〇さん」とユーザー名が表示されていること", "PASS", "")
      else
        add_log("✗ 1-016: ログイン状態では、トップページに「こんにちは、〇〇さん」とユーザー名が表示されていること (失敗)", :fail)
        add_result("1-016", "ログイン状態では、トップページに「こんにちは、〇〇さん」とユーザー名が表示されていること", "FAIL", "「こんにちは、#{test_name}さん」という表示が見つかりません")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("1-016", "ログイン状態では、トップページに「こんにちは、〇〇さん」とユーザー名が表示されていること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        # 完了時にprogressログを削除
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_check_1_017(cleanup_logs: true)
    begin
      add_log("　 1-017: ログアウト状態では、ヘッダーに「新規登録」「ログイン」のリンクが存在すること", :check_start)

      # ログアウト処理（1-016でログイン済み）
      add_log("ログイン状態: ログアウト処理中...", :progress)
      driver.get(base_url)
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # ログアウトリンクがない場合はスキップ
      end

      # トップページでヘッダーリンクを確認
      add_log("ログアウト状態: ヘッダーリンクを確認中...", :progress)
      driver.get(base_url)

      signup_exists = false
      login_exists = false

      begin
        driver.find_element(:link_text, '新規登録')
        signup_exists = true
      rescue
        signup_exists = false
      end

      begin
        driver.find_element(:link_text, 'ログイン')
        login_exists = true
      rescue
        login_exists = false
      end

      if signup_exists && login_exists
        add_log("✓ 1-017: ログアウト状態では、ヘッダーに「新規登録」「ログイン」のリンクが存在すること", :success)
        add_result("1-017", "ログアウト状態では、ヘッダーに「新規登録」「ログイン」のリンクが存在すること", "PASS", "")
      else
        missing_links = []
        missing_links << "新規登録" unless signup_exists
        missing_links << "ログイン" unless login_exists
        add_log("✗ 1-017: ログアウト状態では、ヘッダーに「新規登録」「ログイン」のリンクが存在すること (失敗)", :fail)
        add_result("1-017", "ログアウト状態では、ヘッダーに「新規登録」「ログイン」のリンクが存在すること", "FAIL", "以下のリンクが見つかりません: #{missing_links.join(', ')}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("1-017", "ログアウト状態では、ヘッダーに「新規登録」「ログイン」のリンクが存在すること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        # 完了時にprogressログを削除
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_check_1_018(cleanup_logs: true)
    begin
      add_log("　 1-018: ユーザーの新規登録には、パスワードとパスワード確認用の値の一致が必須であること", :check_start)

      # テストデータを準備
      test_email = "password-match-test-#{Time.now.to_i}@example.com"

      # 新規登録ページに移動
      add_log("ログアウト状態: 新規登録ページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_up")
      sleep 2

      # フォームに入力（確認用パスワードだけ異なる値）
      add_log("ログアウト状態: 全項目を入力中...", :progress)
      set_element_value_with_retry('user_email', test_email)
      set_element_value_with_retry('user_password', 'aaa111')
      set_element_value_with_retry('user_password_confirmation', 'iii222')
      set_element_value_with_retry('user_name', 'パスワード不一致テスト')
      set_element_value_with_retry('user_profile', 'テストプロフィール')
      set_element_value_with_retry('user_occupation', 'テスト会社')
      set_element_value_with_retry('user_position', 'テスト役職')

      # 登録ボタンをクリック
      add_log("ログアウト状態: 登録を試行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 2

      # 登録ページに留まっているか確認
      add_log("ログアウト状態: 登録結果を確認中...", :progress)
      current_url = driver.current_url
      is_signup_page = current_url.include?('/users/sign_up') || current_url.include?('/users')

      if is_signup_page && !current_url.end_with?('/')
        add_log("✓ 1-018: ユーザーの新規登録には、パスワードとパスワード確認用の値の一致が必須であること", :success)
        add_result("1-018", "ユーザーの新規登録には、パスワードとパスワード確認用の値の一致が必須であること", "PASS", "")
      else
        add_log("✗ 1-018: ユーザーの新規登録には、パスワードとパスワード確認用の値の一致が必須であること (失敗)", :fail)
        add_result("1-018", "ユーザーの新規登録には、パスワードとパスワード確認用の値の一致が必須であること", "FAIL", "パスワードが一致しなくても登録できてしまいます")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("1-018", "ユーザーの新規登録には、パスワードとパスワード確認用の値の一致が必須であること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        # 完了時にprogressログを削除
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_check_2_001(cleanup_logs: true)
    begin
      add_log("　 2-001: ログイン状態のユーザーだけが、投稿ページへ遷移できること", :check_start)

      # パート1: ログアウト状態で /prototypes/new にアクセスを試みる
      add_log("ログアウト状態: 新規投稿ページへのアクセスを試行中...", :progress)
      driver.get("#{base_url}/prototypes/new")

      # 新規投稿ページに遷移できていないことを確認（ログインページなどにリダイレクトされる）
      current_url_1 = driver.current_url
      is_new_page_1 = current_url_1.include?('/prototypes/new')

      if is_new_page_1
        add_log("✗ 2-001: ログイン状態のユーザーだけが、投稿ページへ遷移できること (失敗)", :fail)
        add_result("2-001", "ログイン状態のユーザーだけが、投稿ページへ遷移できること", "FAIL", "ログアウト状態でも新規投稿ページに遷移できてしまいます")
        return { results: results, logs: logs }
      end

      # パート2: ログインして「New Proto」ボタンから遷移できることを確認
      if @registered_users.empty?
        add_log("✗ 2-001: ログイン状態のユーザーだけが、投稿ページへ遷移できること (失敗)", :fail)
        add_result("2-001", "ログイン状態のユーザーだけが、投稿ページへ遷移できること", "ERROR", "登録済みユーザーが見つかりません")
        return { results: results, logs: logs }
      end

      test_user = @registered_users.first
      test_email = test_user[:email]
      test_password = test_user[:password]

      # ログインページに移動
      add_log("ログアウト状態: ログインページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      # ログイン情報を入力
      add_log("ログアウト状態: ログイン情報を入力中...", :progress)
      set_element_value_with_retry('user_email', test_email)
      set_element_value_with_retry('user_password', test_password)

      # ログインボタンをクリック
      add_log("ログアウト状態: ログイン実行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 3

      # トップページに移動して「New Proto」リンクをクリック
      add_log("ログイン状態: 「New Proto」リンクをクリック中...", :progress)
      driver.get(base_url)

      begin
        new_proto_link = driver.find_element(:link_text, 'New Proto')
        new_proto_link.click
        sleep 2

        # 新規投稿ページに遷移できたことを確認
        current_url_2 = driver.current_url
        is_new_page_2 = current_url_2.include?('/prototypes/new')

        if is_new_page_2
          add_log("✓ 2-001: ログイン状態のユーザーだけが、投稿ページへ遷移できること", :success)
          add_result("2-001", "ログイン状態のユーザーだけが、投稿ページへ遷移できること", "PASS", "")
        else
          add_log("✗ 2-001: ログイン状態のユーザーだけが、投稿ページへ遷移できること (失敗)", :fail)
          add_result("2-001", "ログイン状態のユーザーだけが、投稿ページへ遷移できること", "FAIL", "ログイン状態でも新規投稿ページに遷移できません。現在のURL: #{current_url_2}")
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        add_log("✗ 2-001: ログイン状態のユーザーだけが、投稿ページへ遷移できること (失敗)", :fail)
        add_result("2-001", "ログイン状態のユーザーだけが、投稿ページへ遷移できること", "FAIL", "「New Proto」リンクが見つかりません")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("2-001", "ログイン状態のユーザーだけが、投稿ページへ遷移できること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        # 完了時にprogressログを削除
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_prototype_validation_checks
    # 2-001でログイン済みなので、そのまま各バリデーションをチェック
    # 基本データ
    base_data = {
      title: "テストプロトタイプ",
      catch_copy: "テストキャッチコピー",
      concept: "テストコンセプト",
      image: ensure_test_image
    }

    # 2-002: プロトタイプ名称必須
    check_prototype_required_field("2-002", "プロトタイプの名称が必須であること", base_data, :title, "")

    # 2-003: キャッチコピー必須
    check_prototype_required_field("2-003", "キャッチコピーが必須であること", base_data, :catch_copy, "")

    # 2-004: コンセプト必須
    check_prototype_required_field("2-004", "コンセプトの情報が必須であること", base_data, :concept, "")

    # 2-005: 画像必須
    check_prototype_image_required("2-005", base_data)

    # 2-006: すべて空欄で投稿できないこと
    check_prototype_all_empty("2-006")
  end

  def check_prototype_required_field(check_number, description, base_data, field, invalid_value)
    begin
      add_log("　 #{check_number}: #{description}", :check_start)
      add_log("ログイン状態: #{field}を空にして投稿を試行中...", :progress)

      test_data = base_data.dup
      test_data[field] = invalid_value

      driver.get("#{base_url}/prototypes/new")

      fill_prototype_form(test_data)
      driver.find_element(:name, 'commit').click
      sleep 2

      current_url = driver.current_url
      is_new_page = current_url.include?('/prototypes/new') || current_url.include?('/prototypes') && !current_url.match?(/\/prototypes\/\d+$/)

      if is_new_page && !current_url.end_with?('/')
        add_log("✓ #{check_number}: #{description}", :success)
        add_result(check_number, description, "PASS", "")
      else
        add_log("✗ #{check_number}: #{description} (失敗)", :fail)
        add_result(check_number, description, "FAIL", "#{field}が空でも投稿できてしまいます")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result(check_number, description, "ERROR", e.message)
    end
  end

  def check_prototype_image_required(check_number, base_data)
    begin
      description = "画像は1枚必須であること(ActiveStorageを使用)"
      add_log("　 #{check_number}: #{description}", :check_start)
      add_log("ログイン状態: 画像なしで投稿を試行中...", :progress)

      test_data = base_data.dup
      test_data[:image] = nil

      driver.get("#{base_url}/prototypes/new")

      fill_prototype_form(test_data)
      driver.find_element(:name, 'commit').click
      sleep 2

      current_url = driver.current_url
      is_new_page = current_url.include?('/prototypes/new') || current_url.include?('/prototypes') && !current_url.match?(/\/prototypes\/\d+$/)

      if is_new_page && !current_url.end_with?('/')
        add_log("✓ #{check_number}: #{description}", :success)
        add_result(check_number, description, "PASS", "")
      else
        add_log("✗ #{check_number}: #{description} (失敗)", :fail)
        add_result(check_number, description, "FAIL", "画像なしでも投稿できてしまいます")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result(check_number, description, "ERROR", e.message)
    end
  end

  def check_prototype_all_empty(check_number)
    begin
      description = "投稿に必要な情報が入力されていない場合は、投稿できずにそのページに留まること"
      add_log("　 #{check_number}: #{description}", :check_start)
      add_log("ログイン状態: すべて空欄で投稿を試行中...", :progress)

      driver.get("#{base_url}/prototypes/new")

      # すべて空のまま投稿
      driver.find_element(:name, 'commit').click
      sleep 2

      current_url = driver.current_url
      is_new_page = current_url.include?('/prototypes/new') || current_url.include?('/prototypes') && !current_url.match?(/\/prototypes\/\d+$/)

      if is_new_page && !current_url.end_with?('/')
        add_log("✓ #{check_number}: #{description}", :success)
        add_result(check_number, description, "PASS", "")
      else
        add_log("✗ #{check_number}: #{description} (失敗)", :fail)
        add_result(check_number, description, "FAIL", "空欄でも投稿できてしまいます")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result(check_number, description, "ERROR", e.message)
    end
  end

  def run_check_2_007(cleanup_logs: true)
    begin
      add_log("　 2-007: 必要な情報を入力すると、投稿ができること", :check_start)
      add_log("ログイン中...", :progress)

      # ログイン
      login_with_registered_user

      # テストデータを準備
      test_title = "テスト投稿プロトタイプ#{Time.now.to_i}"
      test_catch_copy = "テストキャッチコピー"
      test_concept = "テストコンセプト"

      # 投稿情報を保存（3-001以降のテストで使用）
      @posted_prototype = {
        title: test_title,
        catch_copy: test_catch_copy,
        concept: test_concept
      }

      # 投稿ページに移動
      add_log("ログイン状態: 投稿ページへ移動中...", :progress)
      driver.get("#{base_url}/prototypes/new")

      # フォームに入力
      add_log("ログイン状態: 必要な情報を入力中...", :progress)
      fill_prototype_form({
        title: test_title,
        catch_copy: test_catch_copy,
        concept: test_concept,
        image: ensure_test_image
      })

      # 投稿ボタンをクリック
      add_log("ログイン状態: 投稿実行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 3

      # 2-008: トップページに遷移したか確認
      add_log("ログイン状態: 投稿結果を確認中...", :progress)
      current_url = driver.current_url
      is_top_page = (current_url == base_url || current_url == "#{base_url}/")

      if is_top_page
        add_log("✓ 2-007: 必要な情報を入力すると、投稿ができること", :success)
        add_result("2-007", "必要な情報を入力すると、投稿ができること", "PASS", "")

        add_log("✓ 2-008: 正しく投稿できた場合は、トップページへ遷移すること", :success)
        add_result("2-008", "正しく投稿できた場合は、トップページへ遷移すること", "PASS", "")

        # 2-009: 投稿した情報がトップページに表示されているか確認
        add_log("　 2-009: 投稿した情報は、トップページに表示されること", :check_start)
        add_log("ログイン状態: 投稿内容の表示を確認中...", :progress)

        page_text = driver.find_element(:tag_name, 'body').text
        if page_text.include?(test_title)
          add_log("✓ 2-009: 投稿した情報は、トップページに表示されること", :success)
          add_result("2-009", "投稿した情報は、トップページに表示されること", "PASS", "")
        else
          add_log("✗ 2-009: 投稿した情報は、トップページに表示されること (失敗)", :fail)
          add_result("2-009", "投稿した情報は、トップページに表示されること", "FAIL", "投稿したプロトタイプがトップページに表示されていません")
        end
      else
        add_log("✗ 2-007: 必要な情報を入力すると、投稿ができること (失敗)", :fail)
        add_result("2-007", "必要な情報を入力すると、投稿ができること", "FAIL", "投稿後に正しいページに遷移しません。現在のURL: #{current_url}")

        add_log("✗ 2-008: 正しく投稿できた場合は、トップページへ遷移すること (失敗)", :fail)
        add_result("2-008", "正しく投稿できた場合は、トップページへ遷移すること", "FAIL", "トップページに遷移しません。現在のURL: #{current_url}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("2-007", "必要な情報を入力すると、投稿ができること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs

      if cleanup_logs
        @logs.reject! { |log| log[:type] == :progress }
      end
    end

    { results: results, logs: logs }
  end

  def run_check_3_001(cleanup_logs: true)
    begin
      add_log("　 3-001: ログイン・ログアウトの状態に関わらず、プロトタイプ一覧を閲覧できること", :check_start)

      # パート1: ログアウト状態で一覧閲覧
      add_log("ログアウト状態: 一覧表示を確認中...", :progress)
      driver.get(base_url)

      # ログアウトリンクがあればログアウト
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # 既にログアウト状態
      end

      driver.get(base_url)

      # 投稿したプロトタイプが表示されているか確認
      page_text = driver.find_element(:tag_name, 'body').text
      logout_can_view = page_text.include?(@posted_prototype[:title])

      # パート2: ログイン状態で一覧閲覧
      add_log("ログイン状態: 一覧表示を確認中...", :progress)
      login_with_registered_user
      driver.get(base_url)

      page_text = driver.find_element(:tag_name, 'body').text
      login_can_view = page_text.include?(@posted_prototype[:title])

      if logout_can_view && login_can_view
        add_log("✓ 3-001: ログイン・ログアウトの状態に関わらず、プロトタイプ一覧を閲覧できること", :success)
        add_result("3-001", "ログイン・ログアウトの状態に関わらず、プロトタイプ一覧を閲覧できること", "PASS", "")
      elsif !logout_can_view
        add_log("✗ 3-001: ログイン・ログアウトの状態に関わらず、プロトタイプ一覧を閲覧できること (失敗)", :fail)
        add_result("3-001", "ログイン・ログアウトの状態に関わらず、プロトタイプ一覧を閲覧できること", "FAIL", "ログアウト状態で一覧が表示されません")
      elsif !login_can_view
        add_log("✗ 3-001: ログイン・ログアウトの状態に関わらず、プロトタイプ一覧を閲覧できること (失敗)", :fail)
        add_result("3-001", "ログイン・ログアウトの状態に関わらず、プロトタイプ一覧を閲覧できること", "FAIL", "ログイン状態で一覧が表示されません")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("3-001", "ログイン・ログアウトの状態に関わらず、プロトタイプ一覧を閲覧できること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs
      @logs.reject! { |log| log[:type] == :progress } if cleanup_logs
    end

    { results: results, logs: logs }
  end

  def run_check_3_002_and_3_003(cleanup_logs: true)
    # 変数の初期化
    has_image = false

    # チェック番号1: 4つの情報表示確認
    begin
      add_log("　 チェック番号1: プロトタイプ毎に、画像・プロトタイプ名・キャッチコピー・投稿者名の、4つの情報について表示できること", :check_start)
      add_log("ログイン状態: 4つの情報の表示を確認中...", :progress)

      driver.get(base_url)

      page_source = driver.page_source
      page_text = driver.find_element(:tag_name, 'body').text

      # 画像の存在確認
      begin
        # 投稿したタイトルを含む要素の近くの画像を探す
        images = driver.find_elements(:tag_name, 'img')
        has_image = images.any? { |img| img.attribute('src') && !img.attribute('src').empty? }
      rescue
        has_image = false
      end

      # プロトタイプ名の存在確認
      has_title = page_text.include?(@posted_prototype[:title])

      # キャッチコピーの存在確認
      has_catch_copy = page_text.include?(@posted_prototype[:catch_copy])

      # 投稿者名の存在確認（登録したユーザー名）
      has_user_name = false
      if @registered_users.any?
        test_user = @registered_users.first
        has_user_name = page_text.include?(test_user[:name])
      end

      missing_items = []
      missing_items << "画像" unless has_image
      missing_items << "プロトタイプ名" unless has_title
      missing_items << "キャッチコピー" unless has_catch_copy
      missing_items << "投稿者名" unless has_user_name

      if missing_items.empty?
        add_log("✓ チェック番号1: プロトタイプ毎に、画像・プロトタイプ名・キャッチコピー・投稿者名の、4つの情報について表示できること", :success)
        add_result("チェック番号1", "プロトタイプ毎に、画像・プロトタイプ名・キャッチコピー・投稿者名の、4つの情報について表示できること", "PASS", "")
      else
        add_log("✗ チェック番号1: プロトタイプ毎に、画像・プロトタイプ名・キャッチコピー・投稿者名の、4つの情報について表示できること (失敗)", :fail)
        add_result("チェック番号1", "プロトタイプ毎に、画像・プロトタイプ名・キャッチコピー・投稿者名の、4つの情報について表示できること", "FAIL", "以下の情報が表示されていません: #{missing_items.join(', ')}")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("チェック番号1", "プロトタイプ毎に、画像・プロトタイプ名・キャッチコピー・投稿者名の、4つの情報について表示できること", "ERROR", e.message)
    end

    # 3-002: 画像表示とリンク切れチェック
    begin
      add_log("　 3-002: 画像が表示されており、画像がリンク切れなどになっていないこと", :check_start)
      add_log("ログイン状態: 画像のリンク切れを確認中...", :progress)

      valid_images = 0
      if has_image
        images = driver.find_elements(:tag_name, 'img')
        images.each do |img|
          src = img.attribute('src')
          if src && !src.empty? && !src.include?('data:image')
            valid_images += 1
          end
        end
      end

      if valid_images > 0
        add_log("✓ 3-002: 画像が表示されており、画像がリンク切れなどになっていないこと", :success)
        add_result("3-002", "画像が表示されており、画像がリンク切れなどになっていないこと", "PASS", "")
      else
        add_log("✗ 3-002: 画像が表示されており、画像がリンク切れなどになっていないこと (失敗)", :fail)
        add_result("3-002", "画像が表示されており、画像がリンク切れなどになっていないこと", "FAIL", "有効な画像が見つかりません")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("3-002", "画像が表示されており、画像がリンク切れなどになっていないこと", "ERROR", e.message)
    end

    # 3-003: 詳細ページ遷移確認
    begin
      add_log("　 3-003: ログイン・ログアウトの状態に関わらず、一覧表示されている画像およびプロトタイプ名をクリックすると、該当するプロトタイプの詳細ページへ遷移すること", :check_start)

      # パート1: ログアウト状態で詳細ページ遷移確認
      add_log("ログアウト状態: 詳細ページへの遷移を確認中...", :progress)

      # ログアウト
      driver.get(base_url)
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # 既にログアウト状態
      end

      driver.get(base_url)

      logout_can_navigate = false
      begin
        prototype_link = driver.find_element(:link_text, @posted_prototype[:title])
        prototype_link.click
        sleep 2

        current_url = driver.current_url
        logout_can_navigate = current_url.match?(/\/prototypes\/\d+/)
      rescue Selenium::WebDriver::Error::NoSuchElementError
        logout_can_navigate = false
      end

      # パート2: ログイン状態で詳細ページ遷移確認
      add_log("ログイン状態: 詳細ページへの遷移を確認中...", :progress)

      login_with_registered_user
      driver.get(base_url)

      login_can_navigate = false
      begin
        prototype_link = driver.find_element(:link_text, @posted_prototype[:title])
        prototype_link.click
        sleep 2

        current_url = driver.current_url
        login_can_navigate = current_url.match?(/\/prototypes\/\d+/)
      rescue Selenium::WebDriver::Error::NoSuchElementError
        login_can_navigate = false
      end

      if logout_can_navigate && login_can_navigate
        add_log("✓ 3-003: ログイン・ログアウトの状態に関わらず、一覧表示されている画像およびプロトタイプ名をクリックすると、該当するプロトタイプの詳細ページへ遷移すること", :success)
        add_result("3-003", "ログイン・ログアウトの状態に関わらず、一覧表示されている画像およびプロトタイプ名をクリックすると、該当するプロトタイプの詳細ページへ遷移すること", "PASS", "")
      elsif !logout_can_navigate
        add_log("✗ 3-003: ログイン・ログアウトの状態に関わらず、一覧表示されている画像およびプロトタイプ名をクリックすると、該当するプロトタイプの詳細ページへ遷移すること (失敗)", :fail)
        add_result("3-003", "ログイン・ログアウトの状態に関わらず、一覧表示されている画像およびプロトタイプ名をクリックすると、該当するプロトタイプの詳細ページへ遷移すること", "FAIL", "ログアウト状態で詳細ページに遷移できません")
      elsif !login_can_navigate
        add_log("✗ 3-003: ログイン・ログアウトの状態に関わらず、一覧表示されている画像およびプロトタイプ名をクリックすると、該当するプロトタイプの詳細ページへ遷移すること (失敗)", :fail)
        add_result("3-003", "ログイン・ログアウトの状態に関わらず、一覧表示されている画像およびプロトタイプ名をクリックすると、該当するプロトタイプの詳細ページへ遷移すること", "FAIL", "ログイン状態で詳細ページに遷移できません")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("3-003", "ログイン・ログアウトの状態に関わらず、一覧表示されている画像およびプロトタイプ名をクリックすると、該当するプロトタイプの詳細ページへ遷移すること", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs
      @logs.reject! { |log| log[:type] == :progress } if cleanup_logs
    end

    { results: results, logs: logs }
  end

  def run_check_4_001_4_002_4_003(cleanup_logs: true)
    begin
      # 詳細ページのURLを取得（3-003の最後で遷移しているはず）
      detail_url = driver.current_url

      # URLが詳細ページでない場合は、一覧から遷移する
      unless detail_url.match?(/\/prototypes\/\d+/)
        add_log("ログイン状態: 詳細ページへ遷移中...", :progress)
        driver.get(base_url)

        begin
          prototype_link = driver.find_element(:link_text, @posted_prototype[:title])
          prototype_link.click
          sleep 2
          detail_url = driver.current_url
        rescue => e
          raise "詳細ページへの遷移に失敗しました: #{e.message}"
        end
      end

      # 詳細ページのURLを保存
      @posted_prototype[:detail_url] = detail_url

      # ===== 4-001: 編集・削除リンクの確認 =====
      add_log("　 4-001: ログイン状態の投稿したユーザーだけに、「編集」「削除」のリンクが存在すること", :check_start)
      add_log("ログアウト状態での編集・削除リンクを確認中...", :progress)

      # パート1: ログアウト状態での確認
      # ログアウト
      driver.get(base_url)
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # 既にログアウト状態
      end

      # 詳細ページに遷移
      driver.get(detail_url)

      # ページが完全に読み込まれるまで待機
      sleep 1
      page_text = driver.find_element(:tag_name, 'body').text
      page_source = driver.page_source

      # 4-001 (ログアウト): 編集・削除リンクが存在しないこと
      logout_has_edit = page_text.include?('編集する') && (page_source.include?('/edit') || page_source.include?('edit'))
      logout_has_delete = page_text.include?('削除する') && (page_source.include?('delete') || page_source.include?('destroy'))

      # 4-002 (ログアウト): 5つの情報が表示されること
      logout_has_title = page_text.include?(@posted_prototype[:title])
      logout_has_catch_copy = page_text.include?(@posted_prototype[:catch_copy])
      logout_has_concept = page_text.include?(@posted_prototype[:concept])
      logout_has_user_name = page_text.include?(@registered_users.first[:name]) if @registered_users.any?

      logout_has_image = false
      begin
        images = driver.find_elements(:tag_name, 'img')
        logout_has_image = images.any? { |img| img.attribute('src') && !img.attribute('src').empty? }
      rescue
        logout_has_image = false
      end

      # ===== パート2: 投稿者でログイン状態での確認 =====
      add_log("ログイン状態（投稿者）: 編集・削除リンクを確認中...", :progress)

      login_with_registered_user
      driver.get(detail_url)

      page_text = driver.find_element(:tag_name, 'body').text
      page_source = driver.page_source

      # 4-001 (投稿者): 編集・削除リンクが存在すること
      owner_has_edit = page_text.include?('編集する') && (page_source.include?('/edit') || page_source.include?('edit'))
      owner_has_delete = page_text.include?('削除する') && (page_source.include?('delete') || page_source.include?('destroy'))

      # 4-002 (投稿者): 5つの情報が表示されること
      owner_has_title = page_text.include?(@posted_prototype[:title])
      owner_has_catch_copy = page_text.include?(@posted_prototype[:catch_copy])
      owner_has_concept = page_text.include?(@posted_prototype[:concept])
      owner_has_user_name = page_text.include?(@registered_users.first[:name]) if @registered_users.any?

      owner_has_image = false
      begin
        images = driver.find_elements(:tag_name, 'img')
        owner_has_image = images.any? { |img| img.attribute('src') && !img.attribute('src').empty? }
      rescue
        owner_has_image = false
      end

      # ===== パート3: 別のユーザーでログイン状態での確認 =====
      add_log("ログイン状態（別ユーザー）: 編集・削除リンクを確認中...", :progress)

      # ログアウト
      driver.get(base_url)
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # 既にログアウト状態
      end

      # 既存の2人目のユーザーを使用（セクション1で登録済み）
      if @registered_users.length >= 2
        other_user = @registered_users[1]
      else
        raise "別のユーザーが登録されていません。@registered_usersに2人以上のユーザーが必要です。"
      end

      # 2人目のユーザーでログイン
      driver.get("#{base_url}/users/sign_in")

      # 要素が読み込まれるまで待機
      begin
        driver.find_element(:id, 'user_email')
      rescue
        sleep 1
        driver.find_element(:id, 'user_email')
      end

      set_element_value_with_retry('user_email', other_user[:email])
      set_element_value_with_retry('user_password', other_user[:password])
      driver.find_element(:name, 'commit').click
      sleep 2

      driver.get(detail_url)

      page_text = driver.find_element(:tag_name, 'body').text
      page_source = driver.page_source

      # 4-001 (別ユーザー): 編集・削除リンクが存在しないこと
      other_has_edit = page_text.include?('編集する') && (page_source.include?('/edit') || page_source.include?('edit'))
      other_has_delete = page_text.include?('削除する') && (page_source.include?('delete') || page_source.include?('destroy'))

      # ===== 4-001の結果判定 =====
      if !logout_has_edit && !logout_has_delete && owner_has_edit && owner_has_delete && !other_has_edit && !other_has_delete
        add_log("✓ 4-001: ログイン状態の投稿したユーザーだけに、「編集」「削除」のリンクが存在すること", :success)
        add_result("4-001", "ログイン状態の投稿したユーザーだけに、「編集」「削除」のリンクが存在すること", "PASS", "")
      else
        issues = []
        issues << "ログアウト状態で編集・削除リンクが表示されています" if logout_has_edit || logout_has_delete
        issues << "投稿者でログイン時に編集・削除リンクが表示されていません" if !owner_has_edit || !owner_has_delete
        issues << "別のユーザーでログイン時に編集・削除リンクが表示されています" if other_has_edit || other_has_delete

        add_log("✗ 4-001: ログイン状態の投稿したユーザーだけに、「編集」「削除」のリンクが存在すること (失敗)", :fail)
        add_result("4-001", "ログイン状態の投稿したユーザーだけに、「編集」「削除」のリンクが存在すること", "FAIL", issues.join('; '))
      end

      # ===== 4-002: プロダクト情報の確認 =====
      add_log("　 4-002: ログイン・ログアウトの状態に関わらず、プロダクトの情報（プロトタイプ名・投稿者・画像・キャッチコピー・コンセプト）が表示されていること", :check_start)
      add_log("ログイン状態: プロダクト情報を確認中...", :progress)

      logout_all_displayed = logout_has_title && logout_has_catch_copy && logout_has_concept && logout_has_user_name && logout_has_image
      owner_all_displayed = owner_has_title && owner_has_catch_copy && owner_has_concept && owner_has_user_name && owner_has_image

      if logout_all_displayed && owner_all_displayed
        add_log("✓ 4-002: ログイン・ログアウトの状態に関わらず、プロダクトの情報（プロトタイプ名・投稿者・画像・キャッチコピー・コンセプト）が表示されていること", :success)
        add_result("4-002", "ログイン・ログアウトの状態に関わらず、プロダクトの情報（プロトタイプ名・投稿者・画像・キャッチコピー・コンセプト）が表示されていること", "PASS", "")
      else
        missing_items = []

        if !logout_all_displayed
          logout_missing = []
          logout_missing << "プロトタイプ名" unless logout_has_title
          logout_missing << "キャッチコピー" unless logout_has_catch_copy
          logout_missing << "コンセプト" unless logout_has_concept
          logout_missing << "投稿者" unless logout_has_user_name
          logout_missing << "画像" unless logout_has_image
          missing_items << "ログアウト状態: #{logout_missing.join(', ')}"
        end

        if !owner_all_displayed
          owner_missing = []
          owner_missing << "プロトタイプ名" unless owner_has_title
          owner_missing << "キャッチコピー" unless owner_has_catch_copy
          owner_missing << "コンセプト" unless owner_has_concept
          owner_missing << "投稿者" unless owner_has_user_name
          owner_missing << "画像" unless owner_has_image
          missing_items << "ログイン状態: #{owner_missing.join(', ')}"
        end

        add_log("✗ 4-002: ログイン・ログアウトの状態に関わらず、プロダクトの情報（プロトタイプ名・投稿者・画像・キャッチコピー・コンセプト）が表示されていること (失敗)", :fail)
        add_result("4-002", "ログイン・ログアウトの状態に関わらず、プロダクトの情報（プロトタイプ名・投稿者・画像・キャッチコピー・コンセプト）が表示されていること", "FAIL", "以下の情報が表示されていません: #{missing_items.join('; ')}")
      end

      # ===== 4-003の結果判定 =====
      add_log("　 4-003: 画像が表示されており、画像がリンク切れなどになっていないこと", :check_start)
      add_log("ログイン状態: 画像を確認中...", :progress)

      # 詳細ページに再度アクセスして画像を確認
      driver.get(detail_url)

      valid_images = 0
      begin
        images = driver.find_elements(:tag_name, 'img')
        images.each do |img|
          src = img.attribute('src')
          if src && !src.empty? && !src.include?('data:image')
            valid_images += 1
          end
        end
      rescue
        valid_images = 0
      end

      if valid_images > 0
        add_log("✓ 4-003: 画像が表示されており、画像がリンク切れなどになっていないこと", :success)
        add_result("4-003", "画像が表示されており、画像がリンク切れなどになっていないこと", "PASS", "")
      else
        add_log("✗ 4-003: 画像が表示されており、画像がリンク切れなどになっていないこと (失敗)", :fail)
        add_result("4-003", "画像が表示されており、画像がリンク切れなどになっていないこと", "FAIL", "有効な画像が見つかりません")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("4-001/4-002/4-003", "プロトタイプ詳細表示機能テスト", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs
      @logs.reject! { |log| log[:type] == :progress } if cleanup_logs
    end

    { results: results, logs: logs }
  end

  def run_check_5_001_to_5_005(cleanup_logs: true)
    begin
      # 前提: 4-003で別のユーザーでログインして終わっているので、投稿者で再ログイン
      # @posted_prototypeに投稿したプロトタイプの情報がある

      detail_url = @posted_prototype[:detail_url] || driver.current_url

      # ===== 5-001: 正常な編集ができること =====
      add_log("　 5-001: 投稿に必要な情報を入力すると、プロトタイプが編集できること", :check_start)
      add_log("ログアウト状態: 投稿者で再ログイン中...", :progress)

      # 投稿者で再ログイン
      # 確実にログアウト
      driver.get(base_url)
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # 既にログアウト状態
      end

      # 投稿者（1人目のユーザー）でログイン
      test_user = @registered_users.first
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      set_element_value_with_retry('user_email', test_user[:email])
      set_element_value_with_retry('user_password', test_user[:password])
      driver.find_element(:name, 'commit').click
      sleep 3

      # ログイン確認（トップページにいるはず）
      current_url = driver.current_url
      unless current_url == base_url || current_url == "#{base_url}/"
        raise "ログインに失敗しました。現在のURL: #{current_url}"
      end

      add_log("ログイン状態: 編集ページへ移動中...", :progress)

      # 編集ページに移動
      edit_url = detail_url.gsub(/\/prototypes\/(\d+)$/, '/prototypes/\1/edit')
      driver.get(edit_url)
      sleep 2

      # 編集ページのURLを保存（9-001などで使用）
      @posted_prototype[:edit_url] = driver.current_url

      # 新しい値で編集
      new_title = "編集後のタイトル#{Time.now.to_i}"
      new_catch_copy = "編集後のキャッチコピー"
      new_concept = "編集後のコンセプト"

      driver.execute_script("document.getElementById('prototype_title').value = '#{new_title}';")
      driver.execute_script("document.getElementById('prototype_catch_copy').value = '#{new_catch_copy}';")
      driver.execute_script("document.getElementById('prototype_concept').value = '#{new_concept}';")

      # 更新ボタンをクリック
      driver.find_element(:name, 'commit').click
      sleep 3

      # 詳細ページに遷移したか確認
      current_url = driver.current_url
      is_detail_page = current_url.match?(/\/prototypes\/\d+$/)

      if is_detail_page
        # 編集内容が反映されているか確認
        page_text = driver.find_element(:tag_name, 'body').text

        has_new_title = page_text.include?(new_title)
        has_new_catch_copy = page_text.include?(new_catch_copy)
        has_new_concept = page_text.include?(new_concept)

        if has_new_title && has_new_catch_copy && has_new_concept
          add_log("✓ 5-001: 投稿に必要な情報を入力すると、プロトタイプが編集できること", :success)
          add_result("5-001", "投稿に必要な情報を入力すると、プロトタイプが編集できること", "PASS", "")

          # 編集後の情報を保存
          @posted_prototype[:title] = new_title
          @posted_prototype[:catch_copy] = new_catch_copy
          @posted_prototype[:concept] = new_concept
        else
          missing = []
          missing << "プロトタイプ名" unless has_new_title
          missing << "キャッチコピー" unless has_new_catch_copy
          missing << "コンセプト" unless has_new_concept
          add_log("✗ 5-001: 投稿に必要な情報を入力すると、プロトタイプが編集できること (失敗)", :fail)
          add_result("5-001", "投稿に必要な情報を入力すると、プロトタイプが編集できること", "FAIL", "編集内容が反映されていません: #{missing.join(', ')}")
        end
      else
        add_log("✗ 5-001: 投稿に必要な情報を入力すると、プロトタイプが編集できること (失敗)", :fail)
        add_result("5-001", "投稿に必要な情報を入力すると、プロトタイプが編集できること", "FAIL", "詳細ページに遷移していません。現在のURL: #{current_url}")
      end

      # ===== 5-002: 何も編集せずに更新 → 画像が残る確認 =====
      add_log("　 5-002: 何も編集せずに更新をしても、画像無しのプロトタイプにならないこと", :check_start)
      add_log("ログイン状態: 何も編集せずに更新中...", :progress)

      # 編集ページに戻る
      driver.get(current_url.gsub(/\/prototypes\/(\d+)$/, '/prototypes/\1/edit'))

      # 何も変更せずに更新ボタンをクリック
      driver.find_element(:name, 'commit').click
      sleep 3

      # 詳細ページに遷移したか確認
      current_url = driver.current_url
      is_detail_page = current_url.match?(/\/prototypes\/\d+$/)

      if is_detail_page
        # 画像が残っているか確認
        images = driver.find_elements(:tag_name, 'img')
        has_image = images.any? { |img| img.attribute('src') && !img.attribute('src').empty? && !img.attribute('src').include?('data:image') }

        if has_image
          add_log("✓ 5-002: 何も編集せずに更新をしても、画像無しのプロトタイプにならないこと", :success)
          add_result("5-002", "何も編集せずに更新をしても、画像無しのプロトタイプにならないこと", "PASS", "")
        else
          add_log("✗ 5-002: 何も編集せずに更新をしても、画像無しのプロトタイプにならないこと (失敗)", :fail)
          add_result("5-002", "何も編集せずに更新をしても、画像無しのプロトタイプにならないこと", "FAIL", "更新後に画像が消えています")
        end
      else
        add_log("✗ 5-002: 何も編集せずに更新をしても、画像無しのプロトタイプにならないこと (失敗)", :fail)
        add_result("5-002", "何も編集せずに更新をしても、画像無しのプロトタイプにならないこと", "FAIL", "詳細ページに遷移していません。現在のURL: #{current_url}")
      end

      # ===== 5-003: 編集ページへの遷移確認 =====
      add_log("　 5-003: ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから編集ボタンをクリックすると、編集ページへ遷移できること", :check_start)
      add_log("ログイン状態: 編集ページへの遷移を確認中...", :progress)

      driver.get(detail_url)

      # 編集ボタンをクリック
      begin
        edit_link = driver.find_element(:link_text, '編集する')
        edit_link.click
        sleep 2

        current_url = driver.current_url
        is_edit_page = current_url.match?(/\/prototypes\/\d+\/edit/)

        if is_edit_page
          add_log("✓ 5-003: ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから編集ボタンをクリックすると、編集ページへ遷移できること", :success)
          add_result("5-003", "ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから編集ボタンをクリックすると、編集ページへ遷移できること", "PASS", "")
        else
          add_log("✗ 5-003: ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから編集ボタンをクリックすると、編集ページへ遷移できること (失敗)", :fail)
          add_result("5-003", "ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから編集ボタンをクリックすると、編集ページへ遷移できること", "FAIL", "編集ページに遷移しません。現在のURL: #{current_url}")
        end
      rescue Selenium::WebDriver::Error::NoSuchElementError
        add_log("✗ 5-003: ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから編集ボタンをクリックすると、編集ページへ遷移できること (失敗)", :fail)
        add_result("5-003", "ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから編集ボタンをクリックすると、編集ページへ遷移できること", "FAIL", "編集ボタンが見つかりません")
        raise
      end

      # ===== チェック番号3: 既存情報の表示確認 =====
      add_log("　 チェック番号3: プロトタイプ情報について、すでに登録されている情報は、編集画面を開いた時点で表示されること", :check_start)
      add_log("ログイン状態: 既存情報の表示を確認中...", :progress)

      # フォームの値を取得
      title_value = driver.execute_script("return document.getElementById('prototype_title').value;")
      catch_copy_value = driver.execute_script("return document.getElementById('prototype_catch_copy').value;")
      concept_value = driver.execute_script("return document.getElementById('prototype_concept').value;")

      has_title = title_value == @posted_prototype[:title]
      has_catch_copy = catch_copy_value == @posted_prototype[:catch_copy]
      has_concept = concept_value == @posted_prototype[:concept]

      if has_title && has_catch_copy && has_concept
        add_log("✓ チェック番号3: プロトタイプ情報について、すでに登録されている情報は、編集画面を開いた時点で表示されること", :success)
        add_result("チェック番号3", "プロトタイプ情報について、すでに登録されている情報は、編集画面を開いた時点で表示されること", "PASS", "")
      else
        missing = []
        missing << "プロトタイプ名" unless has_title
        missing << "キャッチコピー" unless has_catch_copy
        missing << "コンセプト" unless has_concept
        add_log("✗ チェック番号3: プロトタイプ情報について、すでに登録されている情報は、編集画面を開いた時点で表示されること (失敗)", :fail)
        add_result("チェック番号3", "プロトタイプ情報について、すでに登録されている情報は、編集画面を開いた時点で表示されること", "FAIL", "以下の情報が表示されていません: #{missing.join(', ')}")
      end

      # ===== 5-004: 空欄でページに留まる確認 =====
      add_log("　 5-004: 空の入力欄がある場合は、編集できずにそのページに留まること", :check_start)
      add_log("ログイン状態: titleを空にして更新を試行中...", :progress)

      # titleを空にする
      driver.execute_script("document.getElementById('prototype_title').value = '';")

      # catch_copyとconceptに値を入力（バリデーションエラー後の確認用）
      driver.execute_script("document.getElementById('prototype_catch_copy').value = 'バリデーションテスト用キャッチコピー';")
      driver.execute_script("document.getElementById('prototype_concept').value = 'バリデーションテスト用コンセプト';")

      # 更新ボタンをクリック
      driver.find_element(:name, 'commit').click
      sleep 2

      # 編集ページに留まっているか確認
      current_url = driver.current_url
      is_still_edit_page = current_url.match?(/\/prototypes\/\d+\/edit/) || current_url.match?(/\/prototypes\/\d+$/)

      if is_still_edit_page
        add_log("✓ 5-004: 空の入力欄がある場合は、編集できずにそのページに留まること", :success)
        add_result("5-004", "空の入力欄がある場合は、編集できずにそのページに留まること", "PASS", "")
      else
        add_log("✗ 5-004: 空の入力欄がある場合は、編集できずにそのページに留まること (失敗)", :fail)
        add_result("5-004", "空の入力欄がある場合は、編集できずにそのページに留まること", "FAIL", "空欄があっても編集できてしまいます")
      end

      # ===== 5-005: 正しく編集できた場合は詳細ページへ遷移すること =====
      add_log("　 5-005: 正しく編集できた場合は、詳細ページへ遷移すること", :check_start)
      add_log("ログイン状態: 正しい値で編集を試行中...", :progress)

      # 編集ページに移動（念のため）
      edit_url = detail_url.gsub(/\/prototypes\/(\d+)$/, '/prototypes/\1/edit')
      driver.get(edit_url)

      # 新しい値で編集
      new_title_for_5005 = "更新後のプロトタイプ#{Time.now.to_i}"
      new_catch_copy_for_5005 = "更新したキャッチコピー"
      new_concept_for_5005 = "編集機能で内容を更新しました"

      driver.execute_script("document.getElementById('prototype_title').value = '#{new_title_for_5005}';")
      driver.execute_script("document.getElementById('prototype_catch_copy').value = '#{new_catch_copy_for_5005}';")
      driver.execute_script("document.getElementById('prototype_concept').value = '#{new_concept_for_5005}';")

      # 更新ボタンをクリック
      driver.find_element(:name, 'commit').click
      sleep 3

      # 詳細ページに遷移したか確認
      current_url = driver.current_url
      is_detail_page = current_url.match?(/\/prototypes\/\d+$/)

      if is_detail_page
        add_log("✓ 5-005: 正しく編集できた場合は、詳細ページへ遷移すること", :success)
        add_result("5-005", "正しく編集できた場合は、詳細ページへ遷移すること", "PASS", "")

        # 編集後の情報を保存
        @posted_prototype[:title] = new_title_for_5005
        @posted_prototype[:catch_copy] = new_catch_copy_for_5005
        @posted_prototype[:concept] = new_concept_for_5005
      else
        add_log("✗ 5-005: 正しく編集できた場合は、詳細ページへ遷移すること (失敗)", :fail)
        add_result("5-005", "正しく編集できた場合は、詳細ページへ遷移すること", "FAIL", "詳細ページに遷移していません。現在のURL: #{current_url}")
      end

      # ===== チェック番号7: バリデーションエラー時に入力保持 =====
      add_log("　 チェック番号7: バリデーションによって投稿ができず、そのページに留まった場合でも、入力済みの項目（画像以外）は消えないこと", :check_start)
      add_log("ログイン状態: 入力済み項目の保持を確認中...", :progress)

      # 編集ページに戻る
      driver.get(current_url.gsub(/\/prototypes\/(\d+)$/, '/prototypes/\1/edit'))

      # titleを空にして、他の項目に値を入れる
      driver.execute_script("document.getElementById('prototype_title').value = '';")
      driver.execute_script("document.getElementById('prototype_catch_copy').value = '入力済みキャッチコピー';")
      driver.execute_script("document.getElementById('prototype_concept').value = '入力済みコンセプト';")

      # 更新ボタンをクリック（バリデーションエラーになるはず）
      driver.find_element(:name, 'commit').click
      sleep 2

      # フォームの値を取得
      catch_copy_after = driver.execute_script("return document.getElementById('prototype_catch_copy').value;")
      concept_after = driver.execute_script("return document.getElementById('prototype_concept').value;")

      # 入力した値が残っているか確認
      catch_copy_kept = catch_copy_after == '入力済みキャッチコピー'
      concept_kept = concept_after == '入力済みコンセプト'

      if catch_copy_kept && concept_kept
        add_log("✓ チェック番号7: バリデーションによって投稿ができず、そのページに留まった場合でも、入力済みの項目（画像以外）は消えないこと", :success)
        add_result("チェック番号7", "バリデーションによって投稿ができず、そのページに留まった場合でも、入力済みの項目（画像以外）は消えないこと", "PASS", "")
      else
        missing = []
        missing << "キャッチコピー" unless catch_copy_kept
        missing << "コンセプト" unless concept_kept
        add_log("✗ チェック番号7: バリデーションによって投稿ができず、そのページに留まった場合でも、入力済みの項目（画像以外）は消えないこと (失敗)", :fail)
        add_result("チェック番号7", "バリデーションによって投稿ができず、そのページに留まった場合でも、入力済みの項目（画像以外）は消えないこと", "FAIL", "以下の項目が消えています: #{missing.join(', ')}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("5-001~5-005", "プロトタイプ編集機能テスト", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs
      @logs.reject! { |log| log[:type] == :progress } if cleanup_logs
    end

    { results: results, logs: logs }
  end

  def run_check_6_001_6_002(cleanup_logs: true)
    begin
      # ===== 6-001: 削除機能のテスト =====
      add_log("　 6-001: ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから削除ボタンをクリックすると、プロトタイプを削除できること", :check_start)
      add_log("ログイン状態: 削除テスト用プロトタイプを投稿中...", :progress)

      # 削除テスト用のプロトタイプを新規投稿
      driver.get("#{base_url}/prototypes/new")
      sleep 2

      @delete_test_prototype = {
        title: "【削除テスト用】プロトタイプ#{Time.now.to_i}",
        catch_copy: "削除テスト用キャッチコピー",
        concept: "削除テスト用コンセプト",
        image: ensure_test_image
      }

      fill_prototype_form(@delete_test_prototype)
      driver.find_element(:name, 'commit').click
      sleep 3

      # 投稿後はトップページにリダイレクトされるべき
      current_url = driver.current_url

      # 詳細ページに遷移した場合はNG（間違った実装）
      if current_url.match?(/\/prototypes\/\d+/)
        raise "投稿後に詳細ページに遷移しました（トップページにリダイレクトされるべきです）: #{current_url}"
      end

      # トップページから一覧で削除テスト用プロトタイプをクリックして詳細ページへ
      driver.get(base_url)
      sleep 2

      begin
        prototype_link = driver.find_element(:link_text, @delete_test_prototype[:title])
        prototype_link.click
        sleep 2
        delete_test_detail_url = driver.current_url
      rescue => e
        raise "削除テスト用プロトタイプの詳細ページへの遷移に失敗しました: #{e.message}"
      end

      @delete_test_prototype[:detail_url] = delete_test_detail_url

      # ===== 削除ボタンの表示確認 =====
      add_log("ログアウト状態での削除ボタンを確認中...", :progress)

      # パート1: ログアウト状態での確認
      driver.get(base_url)
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # 既にログアウト状態
      end

      driver.get(delete_test_detail_url)
      sleep 1
      page_text = driver.find_element(:tag_name, 'body').text
      page_source = driver.page_source

      logout_has_delete = page_text.include?('削除する') && (page_source.include?('delete') || page_source.include?('destroy'))

      # パート2: 別のユーザーでログイン状態での確認
      add_log("ログイン状態（別ユーザー）: 削除ボタンを確認中...", :progress)

      if @registered_users.length >= 2
        other_user = @registered_users[1]
      else
        raise "別のユーザーが登録されていません"
      end

      driver.get("#{base_url}/users/sign_in")
      sleep 2

      set_element_value_with_retry('user_email', other_user[:email])
      set_element_value_with_retry('user_password', other_user[:password])
      driver.find_element(:name, 'commit').click
      sleep 2

      driver.get(delete_test_detail_url)
      sleep 1
      page_text = driver.find_element(:tag_name, 'body').text
      page_source = driver.page_source

      other_user_has_delete = page_text.include?('削除する') && (page_source.include?('delete') || page_source.include?('destroy'))

      # パート3: 投稿者でログイン状態での確認
      add_log("ログイン状態（投稿者）: 削除ボタンを確認中...", :progress)

      driver.get(base_url)
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
      end

      test_user = @registered_users.first
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      set_element_value_with_retry('user_email', test_user[:email])
      set_element_value_with_retry('user_password', test_user[:password])
      driver.find_element(:name, 'commit').click
      sleep 2

      driver.get(delete_test_detail_url)
      sleep 1
      page_text = driver.find_element(:tag_name, 'body').text
      page_source = driver.page_source

      owner_has_delete = page_text.include?('削除する') && (page_source.include?('delete') || page_source.include?('destroy'))

      # ===== 削除実行 =====
      add_log("ログイン状態（投稿者）: 削除を実行中...", :progress)

      begin
        delete_link = driver.find_element(:link_text, '削除する')
        delete_link.click
        sleep 1

        # アラートを受け入れる（削除確認ダイアログ）
        begin
          alert = driver.switch_to.alert
          alert.accept
          sleep 3
        rescue
          # アラートが無い場合はスキップ
        end
      rescue => e
        raise "削除ボタンのクリックに失敗しました: #{e.message}"
      end

      # 削除後のURLを記録（6-002で使用）
      @redirect_url_after_delete = driver.current_url

      # ===== 削除されたか確認 =====
      add_log("ログイン状態（投稿者）: 削除されたか確認中...", :progress)

      # 一覧ページで削除したプロトタイプが無いことを確認
      driver.get(base_url)
      sleep 2
      page_text = driver.find_element(:tag_name, 'body').text

      deleted_prototype_not_found = !page_text.include?(@delete_test_prototype[:title])
      original_prototype_exists = page_text.include?(@posted_prototype[:title])

      # ===== 6-001の結果判定 =====
      if !logout_has_delete && !other_user_has_delete && owner_has_delete && deleted_prototype_not_found && original_prototype_exists
        add_log("✓ 6-001: ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから削除ボタンをクリックすると、プロトタイプを削除できること", :success)
        add_result("6-001", "ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから削除ボタンをクリックすると、プロトタイプを削除できること", "PASS", "")
      else
        issues = []
        issues << "ログアウト状態で削除ボタンが表示されています" if logout_has_delete
        issues << "別のユーザーでログイン時に削除ボタンが表示されています" if other_user_has_delete
        issues << "投稿者でログイン時に削除ボタンが表示されていません" if !owner_has_delete
        issues << "削除したプロトタイプがまだ一覧に表示されています" if !deleted_prototype_not_found
        issues << "既存のプロトタイプが削除されてしまいました" if !original_prototype_exists

        add_log("✗ 6-001: ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから削除ボタンをクリックすると、プロトタイプを削除できること (失敗)", :fail)
        add_result("6-001", "ログイン状態のユーザーに限り、自身の投稿したプロトタイプの詳細ページから削除ボタンをクリックすると、プロトタイプを削除できること", "FAIL", issues.join('; '))
      end

      # ===== 6-002: トップページ遷移確認 =====
      add_log("　 6-002: 削除が完了すると、トップページへ遷移すること", :check_start)

      # 削除後のURLがトップページか確認
      is_top_page = (@redirect_url_after_delete == base_url || @redirect_url_after_delete == "#{base_url}/")

      if is_top_page
        add_log("✓ 6-002: 削除が完了すると、トップページへ遷移すること", :success)
        add_result("6-002", "削除が完了すると、トップページへ遷移すること", "PASS", "")
      else
        add_log("✗ 6-002: 削除が完了すると、トップページへ遷移すること (失敗)", :fail)
        add_result("6-002", "削除が完了すると、トップページへ遷移すること", "FAIL", "削除後のURL: #{@redirect_url_after_delete}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("6-001/6-002", "プロトタイプ削除機能テスト", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs
      @logs.reject! { |log| log[:type] == :progress } if cleanup_logs
    end

    { results: results, logs: logs }
  end

  def run_check_7_001_to_7_004(cleanup_logs: true)
    begin
      # 既存のプロトタイプ（@posted_prototype）を使用
      detail_url = @posted_prototype[:detail_url]

      # ===== 7-001: コメント投稿欄の表示確認 =====
      add_log("　 7-001: コメント投稿欄は、ログイン状態のユーザーへのみ、詳細ページに表示されていること", :check_start)
      add_log("ログアウト状態でのコメント投稿欄を確認中...", :progress)

      # ログアウト
      driver.get(base_url)
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # 既にログアウト状態
      end

      # 詳細ページに遷移
      driver.get(detail_url)
      sleep 1
      page_source = driver.page_source

      # コメント投稿欄があるか確認（フォーム要素の存在）
      logout_has_comment_form = (page_source.include?('comment') || page_source.include?('コメント')) &&
                                (page_source.include?('<textarea') || page_source.include?('text_area') ||
                                 page_source.include?('id="comment_') || page_source.include?("id='comment_"))

      # ログイン状態での確認
      add_log("ログイン状態でのコメント投稿欄を確認中...", :progress)

      login_with_registered_user
      driver.get(detail_url)
      sleep 1
      page_source = driver.page_source

      login_has_comment_form = (page_source.include?('comment') || page_source.include?('コメント')) &&
                               (page_source.include?('<textarea') || page_source.include?('text_area') ||
                                page_source.include?('id="comment_') || page_source.include?("id='comment_"))

      # 7-001の結果判定
      if !logout_has_comment_form && login_has_comment_form
        add_log("✓ 7-001: コメント投稿欄は、ログイン状態のユーザーへのみ、詳細ページに表示されていること", :success)
        add_result("7-001", "コメント投稿欄は、ログイン状態のユーザーへのみ、詳細ページに表示されていること", "PASS", "")
      else
        issues = []
        issues << "ログアウト状態でコメント投稿欄が表示されています" if logout_has_comment_form
        issues << "ログイン状態でコメント投稿欄が表示されていません" if !login_has_comment_form

        add_log("✗ 7-001: コメント投稿欄は、ログイン状態のユーザーへのみ、詳細ページに表示されていること (失敗)", :fail)
        add_result("7-001", "コメント投稿欄は、ログイン状態のユーザーへのみ、詳細ページに表示されていること", "FAIL", issues.join('; '))
      end

      # ===== 7-002: コメント投稿と表示確認 =====
      add_log("　 7-002: 正しくフォームを入力すると、コメントが投稿できること", :check_start)
      add_log("ログイン状態: コメントを投稿中...", :progress)

      # コメント入力
      @test_comment = {
        content: "テストコメント#{Time.now.to_i}",
        user: @registered_users.first[:name]
      }

      # コメントフォームを探して入力（複数のID候補を試す）
      comment_submitted = false
      redirect_url_after_comment = nil

      ['comment_content', 'comment_text', 'comment_comment'].each do |field_id|
        begin
          driver.execute_script("document.getElementById('#{field_id}').value = '#{@test_comment[:content]}';")
          driver.find_element(:name, 'commit').click
          sleep 2
          comment_submitted = true
          redirect_url_after_comment = driver.current_url
          break
        rescue
          # 次のIDを試す
        end
      end

      unless comment_submitted
        raise "コメントフォームが見つかりません"
      end

      # 投稿したコメントが表示されているか確認
      add_log("ログイン状態: 投稿したコメントが表示されているか確認中...", :progress)

      page_text = driver.find_element(:tag_name, 'body').text
      comment_displayed = page_text.include?(@test_comment[:content])

      # 7-002の結果判定
      if comment_submitted && comment_displayed
        add_log("✓ 7-002: 正しくフォームを入力すると、コメントが投稿できること", :success)
        add_result("7-002", "正しくフォームを入力すると、コメントが投稿できること", "PASS", "")
      else
        issues = []
        issues << "コメントが投稿できませんでした" if !comment_submitted
        issues << "投稿したコメントが表示されていません" if !comment_displayed

        add_log("✗ 7-002: 正しくフォームを入力すると、コメントが投稿できること (失敗)", :fail)
        add_result("7-002", "正しくフォームを入力すると、コメントが投稿できること", "FAIL", issues.join('; '))
      end

      # ===== 7-003: 投稿後の遷移確認 =====
      add_log("　 7-003: コメントを投稿すると、詳細ページに戻ってくること", :check_start)

      is_detail_page = redirect_url_after_comment&.match?(/\/prototypes\/\d+/)

      if is_detail_page
        add_log("✓ 7-003: コメントを投稿すると、詳細ページに戻ってくること", :success)
        add_result("7-003", "コメントを投稿すると、詳細ページに戻ってくること", "PASS", "")
      else
        add_log("✗ 7-003: コメントを投稿すると、詳細ページに戻ってくること (失敗)", :fail)
        add_result("7-003", "コメントを投稿すると、詳細ページに戻ってくること", "FAIL", "投稿後のURL: #{redirect_url_after_comment}")
      end

      # ===== チェック番号4: コメントと投稿者名の表示確認 =====
      add_log("　 チェック番号: 4: コメントを投稿すると、投稿したコメントとその投稿者名が、対象プロトタイプの詳細ページにのみ表示されること", :check_start)
      add_log("ログイン状態: コメントと投稿者名の表示を確認中...", :progress)

      # 詳細ページでコメント内容と投稿者名を確認
      driver.get(detail_url)
      sleep 1
      page_text = driver.find_element(:tag_name, 'body').text

      comment_displayed_on_target = page_text.include?(@test_comment[:content])
      user_name_displayed = page_text.include?(@test_comment[:user])

      # 別のプロトタイプで表示されないことを確認
      add_log("ログイン状態: 他のプロトタイプで表示されないか確認中...", :progress)

      # 別のプロトタイプを投稿
      add_log("ログイン状態: 別のプロトタイプを投稿中...", :progress)
      driver.get("#{base_url}/prototypes/new")
      sleep 2

      other_prototype = {
        title: "別のプロトタイプ#{Time.now.to_i}",
        catch_copy: "別のキャッチコピー",
        concept: "別のコンセプト",
        image: ensure_test_image
      }

      fill_prototype_form(other_prototype)
      driver.find_element(:name, 'commit').click
      sleep 3

      # トップページから別のプロトタイプの詳細ページへ
      add_log("ログイン状態: 別のプロトタイプの詳細ページへ遷移中...", :progress)
      driver.get(base_url)
      sleep 2

      begin
        prototype_link = driver.find_element(:link_text, other_prototype[:title])
        prototype_link.click
        sleep 2
        other_detail_url = driver.current_url
      rescue => e
        raise "別のプロトタイプの詳細ページへの遷移に失敗しました: #{e.message}"
      end

      add_log("ログイン状態: 別のプロトタイプでコメントが表示されていないか確認中...", :progress)
      page_text = driver.find_element(:tag_name, 'body').text
      comment_not_displayed_on_other = !page_text.include?(@test_comment[:content])

      # チェック番号4の結果判定
      if comment_displayed_on_target && user_name_displayed && comment_not_displayed_on_other
        add_log("✓ チェック番号: 4: コメントを投稿すると、投稿したコメントとその投稿者名が、対象プロトタイプの詳細ページにのみ表示されること", :success)
        add_result("チェック番号: 4", "コメントを投稿すると、投稿したコメントとその投稿者名が、対象プロトタイプの詳細ページにのみ表示されること", "PASS", "")
      else
        issues = []
        issues << "対象プロトタイプの詳細ページでコメントが表示されていません" if !comment_displayed_on_target
        issues << "投稿者名が表示されていません" if !user_name_displayed
        issues << "別のプロトタイプの詳細ページでコメントが表示されています" if !comment_not_displayed_on_other

        add_log("✗ チェック番号: 4: コメントを投稿すると、投稿したコメントとその投稿者名が、対象プロトタイプの詳細ページにのみ表示されること (失敗)", :fail)
        add_result("チェック番号: 4", "コメントを投稿すると、投稿したコメントとその投稿者名が、対象プロトタイプの詳細ページにのみ表示されること", "FAIL", issues.join('; '))
      end

      # ===== 7-004: バリデーション =====
      add_log("　 7-004: コメントフォームを空のまま投稿しようとすると、投稿できずにプロトタイプ詳細ページに戻ること", :check_start)
      add_log("ログイン状態: 空のコメントで投稿を試行中...", :progress)

      # 元の詳細ページに戻る
      driver.get(detail_url)
      sleep 1

      # コメント投稿前のコメント数を記録
      page_text_before = driver.find_element(:tag_name, 'body').text

      # 空のコメントを投稿
      ['comment_content', 'comment_text', 'comment_comment'].each do |field_id|
        begin
          driver.execute_script("document.getElementById('#{field_id}').value = '';")
          driver.find_element(:name, 'commit').click
          sleep 2
          break
        rescue
          # 次のIDを試す
        end
      end

      current_url = driver.current_url
      is_still_detail_page = current_url.match?(/\/prototypes\/\d+/)

      # 空のコメントが投稿されていないことを確認
      page_text_after = driver.find_element(:tag_name, 'body').text

      # 7-004の結果判定
      if is_still_detail_page
        add_log("✓ 7-004: コメントフォームを空のまま投稿しようとすると、投稿できずにプロトタイプ詳細ページに戻ること", :success)
        add_result("7-004", "コメントフォームを空のまま投稿しようとすると、投稿できずにプロトタイプ詳細ページに戻ること", "PASS", "")
      else
        add_log("✗ 7-004: コメントフォームを空のまま投稿しようとすると、投稿できずにプロトタイプ詳細ページに戻ること (失敗)", :fail)
        add_result("7-004", "コメントフォームを空のまま投稿しようとすると、投稿できずにプロトタイプ詳細ページに戻ること", "FAIL", "現在のURL: #{current_url}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("7-001~7-004", "コメント機能テスト", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs
      @logs.reject! { |log| log[:type] == :progress } if cleanup_logs
    end

    { results: results, logs: logs }
  end

  def run_check_8_001_and_check_5(cleanup_logs: true)
    begin
      user_info = @registered_users.first
      user_name = user_info[:name]

      # ===== 8-001: ユーザー名クリックでの遷移確認 =====
      add_log("　 8-001: ログイン・ログアウトの状態に関わらず、各ページのユーザー名をクリックすると、ユーザーの詳細ページへ遷移すること", :check_start)

      failed_locations = []

      # ▼ ログアウト状態での確認
      add_log("ログアウト中...", :progress)
      logout_if_needed

      # 1. トップページのプロトタイプ一覧のユーザー名
      add_log("ログアウト状態: トップページのユーザー名リンクを確認中...", :progress)
      driver.get(base_url)
      sleep 2
      begin
        driver.find_element(:partial_link_text, user_name).click
        sleep 2
        if driver.current_url.match?(/\/users\/\d+/)
          # ユーザー詳細ページのURLを保存（9-002などで使用）
          @user_detail_url = driver.current_url
        else
          failed_locations << "ログアウト状態: トップページのユーザー名"
        end
      rescue => e
        failed_locations << "ログアウト状態: トップページのユーザー名（リンクが見つかりません）"
      end

      # 2. プロトタイプ詳細ページの投稿者名
      add_log("ログアウト状態: プロトタイプ詳細ページの投稿者名リンクを確認中...", :progress)
      driver.get(@posted_prototype[:detail_url])
      sleep 2
      begin
        driver.find_element(:partial_link_text, user_name).click
        sleep 2
        unless driver.current_url.match?(/\/users\/\d+/)
          failed_locations << "ログアウト状態: プロトタイプ詳細ページの投稿者名"
        end
      rescue => e
        failed_locations << "ログアウト状態: プロトタイプ詳細ページの投稿者名（リンクが見つかりません）"
      end

      # 3. コメント欄のユーザー名
      add_log("ログアウト状態: コメント欄のユーザー名リンクを確認中...", :progress)
      driver.get(@posted_prototype[:detail_url])
      sleep 2
      begin
        # コメント欄にあるユーザー名を探す（複数ある可能性があるので、2つ目以降をコメント欄と判断）
        comment_user_links = driver.find_elements(:partial_link_text, user_name)
        if comment_user_links.size > 1
          comment_user_links.last.click  # 2つ目以降をコメント欄のリンクと判断
          sleep 2
          unless driver.current_url.match?(/\/users\/\d+/)
            failed_locations << "ログアウト状態: コメント欄のユーザー名"
          end
        else
          failed_locations << "ログアウト状態: コメント欄のユーザー名（リンクが見つかりません）"
        end
      rescue => e
        failed_locations << "ログアウト状態: コメント欄のユーザー名（エラー: #{e.message}）"
      end

      # ▼ ログイン状態での確認
      add_log("ログイン中...", :progress)
      login_with_registered_user

      # 4. トップページの「こんにちは〇〇さん」のユーザー名
      add_log("ログイン状態: こんにちは〇〇さんのユーザー名リンクを確認中...", :progress)
      driver.get(base_url)
      sleep 2
      begin
        # 「こんにちは」の近くにあるユーザー名リンクを探す
        driver.find_element(:partial_link_text, user_name).click
        sleep 2
        unless driver.current_url.match?(/\/users\/\d+/)
          failed_locations << "ログイン状態: こんにちは〇〇さんのユーザー名"
        end
      rescue => e
        failed_locations << "ログイン状態: こんにちは〇〇さんのユーザー名（リンクが見つかりません）"
      end

      # 5. ログイン状態: トップページのプロトタイプ一覧のユーザー名
      add_log("ログイン状態: トップページのユーザー名リンクを確認中...", :progress)
      driver.get(base_url)
      sleep 2
      begin
        # 複数のユーザー名リンクがある場合、プロトタイプ一覧のものを選択
        user_links = driver.find_elements(:partial_link_text, user_name)
        if user_links.size > 1
          user_links.last.click  # 「こんにちは」以外のリンクを選択
        else
          user_links.first.click
        end
        sleep 2
        unless driver.current_url.match?(/\/users\/\d+/)
          failed_locations << "ログイン状態: トップページのユーザー名"
        end
      rescue => e
        failed_locations << "ログイン状態: トップページのユーザー名（リンクが見つかりません）"
      end

      # 6. ログイン状態: プロトタイプ詳細ページの投稿者名
      add_log("ログイン状態: プロトタイプ詳細ページの投稿者名リンクを確認中...", :progress)
      driver.get(@posted_prototype[:detail_url])
      sleep 2
      begin
        driver.find_element(:partial_link_text, user_name).click
        sleep 2
        unless driver.current_url.match?(/\/users\/\d+/)
          failed_locations << "ログイン状態: プロトタイプ詳細ページの投稿者名"
        end
      rescue => e
        failed_locations << "ログイン状態: プロトタイプ詳細ページの投稿者名（リンクが見つかりません）"
      end

      # 7. ログイン状態: コメント欄のユーザー名
      add_log("ログイン状態: コメント欄のユーザー名リンクを確認中...", :progress)
      driver.get(@posted_prototype[:detail_url])
      sleep 2
      begin
        # コメント欄にあるユーザー名を探す
        comment_user_links = driver.find_elements(:partial_link_text, user_name)
        if comment_user_links.size > 1
          comment_user_links.last.click  # 2つ目以降をコメント欄のリンクと判断
          sleep 2
          unless driver.current_url.match?(/\/users\/\d+/)
            failed_locations << "ログイン状態: コメント欄のユーザー名"
          end
        else
          failed_locations << "ログイン状態: コメント欄のユーザー名（リンクが見つかりません）"
        end
      rescue => e
        failed_locations << "ログイン状態: コメント欄のユーザー名（エラー: #{e.message}）"
      end

      # 8-001の結果判定
      if failed_locations.empty?
        add_log("✓ 8-001: ログイン・ログアウトの状態に関わらず、各ページのユーザー名をクリックすると、ユーザーの詳細ページへ遷移すること", :success)
        add_result("8-001", "ログイン・ログアウトの状態に関わらず、各ページのユーザー名をクリックすると、ユーザーの詳細ページへ遷移すること", "PASS", "")
      else
        add_log("✗ 8-001: ログイン・ログアウトの状態に関わらず、各ページのユーザー名をクリックすると、ユーザーの詳細ページへ遷移すること (失敗)", :fail)
        add_result("8-001", "ログイン・ログアウトの状態に関わらず、各ページのユーザー名をクリックすると、ユーザーの詳細ページへ遷移すること", "FAIL", "遷移できなかった箇所: #{failed_locations.join('; ')}")
      end

      # ===== チェック番号5: ユーザー詳細ページの表示内容確認 =====
      add_log("　 チェック番号: 5: ログイン・ログアウトの状態に関わらず、ユーザーの詳細ページには、そのユーザーの詳細情報（名前・プロフィール・所属・役職）と、そのユーザーが投稿したプロトタイプが表示されていること", :check_start)

      failed_items = []

      # ▼ ログアウト状態での確認
      add_log("ログアウト中...", :progress)
      logout_if_needed

      add_log("ログアウト状態: ユーザー詳細ページへ遷移中...", :progress)
      driver.get(base_url)
      sleep 2
      begin
        driver.find_element(:partial_link_text, user_name).click
        sleep 2
      rescue => e
        raise "ユーザー詳細ページへの遷移に失敗しました: #{e.message}"
      end

      add_log("ログアウト状態: ユーザー詳細情報を確認中...", :progress)
      page_text = driver.page_source

      # 各項目をチェック
      unless page_text.include?(user_info[:name])
        failed_items << "ログアウト状態: 名前が表示されていません"
      end

      unless page_text.include?(user_info[:profile])
        failed_items << "ログアウト状態: プロフィールが表示されていません"
      end

      unless page_text.include?(user_info[:occupation])
        failed_items << "ログアウト状態: 所属が表示されていません"
      end

      unless page_text.include?(user_info[:position])
        failed_items << "ログアウト状態: 役職が表示されていません"
      end

      # 投稿したプロトタイプが表示されているか
      unless page_text.include?(@posted_prototype[:title])
        failed_items << "ログアウト状態: ユーザーが投稿したプロトタイプが表示されていません"
      end

      # ▼ ログイン状態での確認
      add_log("ログイン中...", :progress)
      login_with_registered_user

      add_log("ログイン状態: ユーザー詳細ページへ遷移中...", :progress)
      driver.get(base_url)
      sleep 2
      begin
        driver.find_element(:partial_link_text, user_name).click
        sleep 2
      rescue => e
        raise "ユーザー詳細ページへの遷移に失敗しました: #{e.message}"
      end

      add_log("ログイン状態: ユーザー詳細情報を確認中...", :progress)
      page_text = driver.page_source

      # 各項目をチェック
      unless page_text.include?(user_info[:name])
        failed_items << "ログイン状態: 名前が表示されていません"
      end

      unless page_text.include?(user_info[:profile])
        failed_items << "ログイン状態: プロフィールが表示されていません"
      end

      unless page_text.include?(user_info[:occupation])
        failed_items << "ログイン状態: 所属が表示されていません"
      end

      unless page_text.include?(user_info[:position])
        failed_items << "ログイン状態: 役職が表示されていません"
      end

      # 投稿したプロトタイプが表示されているか
      unless page_text.include?(@posted_prototype[:title])
        failed_items << "ログイン状態: ユーザーが投稿したプロトタイプが表示されていません"
      end

      # チェック番号5の結果判定
      if failed_items.empty?
        add_log("✓ チェック番号: 5: ログイン・ログアウトの状態に関わらず、ユーザーの詳細ページには、そのユーザーの詳細情報（名前・プロフィール・所属・役職）と、そのユーザーが投稿したプロトタイプが表示されていること", :success)
        add_result("チェック番号: 5", "ログイン・ログアウトの状態に関わらず、ユーザーの詳細ページには、そのユーザーの詳細情報（名前・プロフィール・所属・役職）と、そのユーザーが投稿したプロトタイプが表示されていること", "PASS", "")
      else
        add_log("✗ チェック番号: 5: ログイン・ログアウトの状態に関わらず、ユーザーの詳細ページには、そのユーザーの詳細情報（名前・プロフィール・所属・役職）と、そのユーザーが投稿したプロトタイプが表示されていること (失敗)", :fail)
        add_result("チェック番号: 5", "ログイン・ログアウトの状態に関わらず、ユーザーの詳細ページには、そのユーザーの詳細情報（名前・プロフィール・所属・役職）と、そのユーザーが投稿したプロトタイプが表示されていること", "FAIL", failed_items.join('; '))
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("8-001~チェック番号5", "ユーザー詳細機能テスト", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs
      @logs.reject! { |log| log[:type] == :progress } if cleanup_logs
    end

    { results: results, logs: logs }
  end

  def run_check_9_001_9_002_and_check_6(cleanup_logs: true)
    begin
      # ===== 9-001: ログアウト状態での認証必須ページのリダイレクト =====
      add_log("　 9-001: ログアウト状態のユーザーは、プロトタイプ新規投稿ページ・プロトタイプ編集ページに遷移しようとすると、ログインページにリダイレクトされること", :check_start)

      failed_pages = []

      add_log("ログアウト中...", :progress)
      logout_if_needed

      # 1. 新規投稿ページへのアクセス
      add_log("ログアウト状態: 新規投稿ページへのアクセスを確認中...", :progress)
      driver.get("#{base_url}/prototypes/new")
      sleep 2
      unless driver.current_url.include?('/users/sign_in')
        failed_pages << "新規投稿ページ"
      end

      # 2. 編集ページへのアクセス
      add_log("ログアウト状態: 編集ページへのアクセスを確認中...", :progress)
      driver.get(@posted_prototype[:edit_url])
      sleep 2
      unless driver.current_url.include?('/users/sign_in')
        failed_pages << "編集ページ"
      end

      # 9-001の結果判定
      if failed_pages.empty?
        add_log("✓ 9-001: ログアウト状態のユーザーは、プロトタイプ新規投稿ページ・プロトタイプ編集ページに遷移しようとすると、ログインページにリダイレクトされること", :success)
        add_result("9-001", "ログアウト状態のユーザーは、プロトタイプ新規投稿ページ・プロトタイプ編集ページに遷移しようとすると、ログインページにリダイレクトされること", "PASS", "")
      else
        add_log("✗ 9-001: ログアウト状態のユーザーは、プロトタイプ新規投稿ページ・プロトタイプ編集ページに遷移しようとすると、ログインページにリダイレクトされること (失敗)", :fail)
        add_result("9-001", "ログアウト状態のユーザーは、プロトタイプ新規投稿ページ・プロトタイプ編集ページに遷移しようとすると、ログインページにリダイレクトされること", "FAIL", "ログインページにリダイレクトされなかった: #{failed_pages.join(', ')}")
      end

      # ===== 9-002: ログアウト状態でアクセス可能なページ =====
      add_log("　 9-002: ログアウト状態のユーザーであっても、トップページ・プロトタイプ詳細ページ・ユーザー詳細ページ・ユーザー新規登録ページ・ログインページには遷移できること", :check_start)

      failed_accessible_pages = []

      # 1. トップページ
      add_log("ログアウト状態: トップページへのアクセスを確認中...", :progress)
      driver.get(base_url)
      sleep 2
      current_url = driver.current_url
      if !(current_url == base_url || current_url == "#{base_url}/")
        failed_accessible_pages << "トップページ（リダイレクトされました: #{current_url}）"
      end

      # 2. プロトタイプ詳細ページ
      add_log("ログアウト状態: プロトタイプ詳細ページへのアクセスを確認中...", :progress)
      driver.get(@posted_prototype[:detail_url])
      sleep 2
      unless driver.current_url == @posted_prototype[:detail_url]
        failed_accessible_pages << "プロトタイプ詳細ページ（リダイレクトされました: #{driver.current_url}）"
      end

      # 3. ユーザー詳細ページ
      add_log("ログアウト状態: ユーザー詳細ページへのアクセスを確認中...", :progress)
      driver.get(@user_detail_url)
      sleep 2
      unless driver.current_url == @user_detail_url
        failed_accessible_pages << "ユーザー詳細ページ（リダイレクトされました: #{driver.current_url}）"
      end

      # 4. ユーザー新規登録ページ
      add_log("ログアウト状態: ユーザー新規登録ページへのアクセスを確認中...", :progress)
      driver.get("#{base_url}/users/sign_up")
      sleep 2
      unless driver.current_url.include?('/users/sign_up')
        failed_accessible_pages << "ユーザー新規登録ページ（リダイレクトされました: #{driver.current_url}）"
      end

      # 5. ログインページ
      add_log("ログアウト状態: ログインページへのアクセスを確認中...", :progress)
      driver.get("#{base_url}/users/sign_in")
      sleep 2
      unless driver.current_url.include?('/users/sign_in')
        failed_accessible_pages << "ログインページ（リダイレクトされました: #{driver.current_url}）"
      end

      # 9-002の結果判定
      if failed_accessible_pages.empty?
        add_log("✓ 9-002: ログアウト状態のユーザーであっても、トップページ・プロトタイプ詳細ページ・ユーザー詳細ページ・ユーザー新規登録ページ・ログインページには遷移できること", :success)
        add_result("9-002", "ログアウト状態のユーザーであっても、トップページ・プロトタイプ詳細ページ・ユーザー詳細ページ・ユーザー新規登録ページ・ログインページには遷移できること", "PASS", "")
      else
        add_log("✗ 9-002: ログアウト状態のユーザーであっても、トップページ・プロトタイプ詳細ページ・ユーザー詳細ページ・ユーザー新規登録ページ・ログインページには遷移できること (失敗)", :fail)
        add_result("9-002", "ログアウト状態のユーザーであっても、トップページ・プロトタイプ詳細ページ・ユーザー詳細ページ・ユーザー新規登録ページ・ログインページには遷移できること", "FAIL", "アクセスできなかったページ: #{failed_accessible_pages.join('; ')}")
      end

      # ===== チェック番号6: 他ユーザーのプロトタイプ編集の制限 =====
      add_log("　 チェック番号: 6: ログイン状態のユーザーであっても、他のユーザーのプロトタイプ編集ページのURLを直接入力して遷移しようとすると、トップページにリダイレクトされること", :check_start)

      # 2人目のユーザーでログイン（@registered_users[1]が存在する想定）
      add_log("2人目のユーザーでログイン中...", :progress)

      if @registered_users.size < 2
        raise "2人目のユーザーが登録されていません。1-002と1-011が正常に実行されている必要があります。"
      end

      second_user = @registered_users[1]
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      set_element_value_with_retry('user_email', second_user[:email])
      set_element_value_with_retry('user_password', second_user[:password])
      driver.find_element(:name, 'commit').click
      sleep 2

      # 1人目のユーザーの編集ページにアクセス
      add_log("ログイン状態（2人目のユーザー）: 他のユーザーの編集ページへのアクセスを確認中...", :progress)
      driver.get(@posted_prototype[:edit_url])
      sleep 2

      current_url = driver.current_url
      is_top_page = (current_url == base_url || current_url == "#{base_url}/")

      # チェック番号6の結果判定
      if is_top_page
        add_log("✓ チェック番号: 6: ログイン状態のユーザーであっても、他のユーザーのプロトタイプ編集ページのURLを直接入力して遷移しようとすると、トップページにリダイレクトされること", :success)
        add_result("チェック番号: 6", "ログイン状態のユーザーであっても、他のユーザーのプロトタイプ編集ページのURLを直接入力して遷移しようとすると、トップページにリダイレクトされること", "PASS", "")
      else
        add_log("✗ チェック番号: 6: ログイン状態のユーザーであっても、他のユーザーのプロトタイプ編集ページのURLを直接入力して遷移しようとすると、トップページにリダイレクトされること (失敗)", :fail)
        add_result("チェック番号: 6", "ログイン状態のユーザーであっても、他のユーザーのプロトタイプ編集ページのURLを直接入力して遷移しようとすると、トップページにリダイレクトされること", "FAIL", "トップページにリダイレクトされませんでした。現在のURL: #{current_url}")
      end

    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result("9-001~チェック番号6", "その他機能テスト", "ERROR", e.message)
    ensure
      cleanup if cleanup_logs
      @logs.reject! { |log| log[:type] == :progress } if cleanup_logs
    end

    { results: results, logs: logs }
  end

  def fill_prototype_form(data)
    # 要素が読み込まれるまで待機
    begin
      driver.find_element(:id, 'prototype_title')
    rescue
      sleep 1
      driver.find_element(:id, 'prototype_title')
    end

    driver.execute_script("document.getElementById('prototype_title').value = '#{data[:title]}';") if data[:title]
    driver.execute_script("document.getElementById('prototype_catch_copy').value = '#{data[:catch_copy]}';") if data[:catch_copy]
    driver.execute_script("document.getElementById('prototype_concept').value = '#{data[:concept]}';") if data[:concept]

    # 画像アップロード
    if data[:image]
      begin
        image_input = driver.find_element(:id, 'prototype_image')
        image_input.send_keys(data[:image])
      rescue => e
        Rails.logger.warn "画像アップロードエラー: #{e.message}"
      end
    end
  end

  def login_with_registered_user
    if @registered_users.empty?
      add_log("エラー: 登録済みユーザーが存在しません", :error)
      raise "登録済みユーザーが存在しません。先にユーザー登録テストを実行してください。"
    end

    test_user = @registered_users.first
    if test_user.nil? || test_user[:email].nil? || test_user[:password].nil?
      add_log("エラー: ユーザー情報が不正です", :error)
      raise "ユーザー情報が不正です: #{test_user.inspect}"
    end

    driver.get("#{base_url}/users/sign_in")
    sleep 2

    # リトライ付きで要素に値を設定
    set_element_value_with_retry('user_email', test_user[:email])
    set_element_value_with_retry('user_password', test_user[:password])
    driver.find_element(:name, 'commit').click
    sleep 2
  end

  def logout_if_needed
    driver.get(base_url)
    sleep 1
    begin
      logout_link = driver.find_element(:link_text, 'ログアウト')
      logout_link.click
      sleep 2
    rescue
      # 既にログアウト状態
    end
  end

  # 要素が見つかるまで待機してから値を設定（リトライ付き）
  def set_element_value_with_retry(element_id, value, max_retries: 3)
    retries = 0
    begin
      driver.execute_script("document.getElementById('#{element_id}').value = '#{value}';")
    rescue => e
      if retries < max_retries
        retries += 1
        sleep 1
        retry
      else
        raise e
      end
    end
  end

  # 要素が見つかるまで待機（リトライ付き）
  def wait_for_element(selector_type, selector_value, max_retries: 5)
    retries = 0
    begin
      driver.find_element(selector_type, selector_value)
    rescue Selenium::WebDriver::Error::NoSuchElementError => e
      if retries < max_retries
        retries += 1
        sleep 1
        retry
      else
        raise e
      end
    end
  end

  def ensure_test_image
    # ユーザーが用意したsakura.jpgを優先的に使用
    sakura_path = Rails.root.join('public', 'images', 'sakura.jpg').to_s
    return sakura_path if File.exist?(sakura_path)

    # sakura.jpgがない場合は既存のロジックを使用
    image_path = '/tmp/test_prototype_image.jpg'

    unless File.exist?(image_path)
      # 小さなテスト画像を作成（ImageMagick使用）
      system("convert -size 100x100 xc:blue #{image_path} 2>/dev/null")

      # ImageMagickがない場合は、base64でダミー画像を作成
      unless File.exist?(image_path)
        require 'base64'
        # 1x1の青いJPEG画像（base64）
        image_data = Base64.decode64('/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAIBAQIBAQICAgICAgICAwUDAwMDAwYEBAMFBwYHBwcGBwcICQsJCAgKCAcHCg0KCgsMDAwMBwkODw0MDgsMDAz/2wBDAQICAgMDAwYDAwYMCAcIDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAz/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA8A/9k=')
        File.binwrite(image_path, image_data)
      end
    end

    image_path
  end

  private

  def check_cancelled
    if @session_id && @sessions_store && @sessions_store[@session_id]
      if @sessions_store[@session_id][:cancelled]
        add_log("テストが中止されました", :error)
        cleanup
        raise "Test cancelled by user"
      end
    end
  end

  def take_full_page_screenshot(filepath)
    begin
      # 現在のウィンドウサイズを保存
      current_width = driver.execute_script("return window.outerWidth")
      current_height = driver.execute_script("return window.outerHeight")

      # ページ全体の高さを取得
      total_height = driver.execute_script("return Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)")
      viewport_width = driver.execute_script("return window.innerWidth") || 1280

      # ウィンドウサイズをページ全体に合わせて調整
      driver.manage.window.resize_to(viewport_width + 20, total_height + 100)
      sleep 0.5

      # スクリーンショットを撮影
      driver.save_screenshot(filepath)

      # 元のサイズに戻す
      driver.manage.window.resize_to(current_width, current_height)
    rescue => e
      # エラー時は通常のスクリーンショットを撮影
      Rails.logger.warn "フルページスクリーンショット失敗、通常撮影に切り替え: #{e.message}"
      driver.save_screenshot(filepath)
    end
  end

  def add_result(check_number, description, status, note)
    # 失敗時はスクリーンショットを撮影
    screenshot_path = nil
    if (status == 'FAIL' || status == 'ERROR') && driver
      begin
        # スクリーンショット保存用ディレクトリを作成（公開ディレクトリ）
        screenshot_dir = Rails.root.join('public', 'screenshots', 'failures')
        FileUtils.mkdir_p(screenshot_dir)

        # ファイル名: チェック番号_タイムスタンプ.png
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        screenshot_filename = "#{check_number.to_s.gsub(/[^a-zA-Z0-9\-]/, '_')}_#{timestamp}.png"
        screenshot_path = screenshot_dir.join(screenshot_filename).to_s

        # フルページスクリーンショットを保存
        take_full_page_screenshot(screenshot_path)

        # 失敗スクリーンショット情報を保存
        failure_screenshot_info = {
          name: "#{check_number} - #{description}",
          filename: screenshot_filename,
          path: "/screenshots/failures/#{screenshot_filename}",
          check_number: check_number
        }

        @failure_screenshots << failure_screenshot_info

        # セッションに即座に失敗スクリーンショット情報を追加
        if @sessions_store && @session_id && @sessions_store[@session_id]
          @sessions_store[@session_id][:failure_screenshots] ||= []
          @sessions_store[@session_id][:failure_screenshots] << failure_screenshot_info
        end

        # noteにスクリーンショットのパスを追加
        note = "#{note}\nスクリーンショット: /screenshots/failures/#{screenshot_filename}" if note.present?
        note = "スクリーンショット: /screenshots/failures/#{screenshot_filename}" if note.blank?
      rescue => e
        Rails.logger.warn "スクリーンショット撮影エラー: #{e.message}"
      end
    end

    results << {
      check_number: check_number,
      description: description,
      status: status,
      note: note,
      screenshot: screenshot_path
    }

    # セッションストアに結果を保存
    if @sessions_store && @session_id && @sessions_store[@session_id]
      @sessions_store[@session_id][:results] = results
    end
  end

  def add_log(message, type = :info)
    log_entry = { message: message, type: type }

    # success/fail/errorログの場合、最後のcheck_startログを探して置き換える
    if [:success, :fail, :error].include?(type)
      check_start_index = @logs.rindex { |log| log[:type] == :check_start }
      if check_start_index
        # check_start以降のprogressログを削除
        @logs.delete_if.with_index { |log, index| index > check_start_index && log[:type] == :progress }
        # check_startログを置き換え
        @logs[check_start_index] = log_entry
      else
        logs << log_entry
      end
    else
      logs << log_entry
    end

    @log_callback.call(log_entry) if @log_callback
  end

  # 最後のprogressログを削除
  def remove_last_progress_log
    progress_index = @logs.rindex { |log| log[:type] == :progress }
    @logs.delete_at(progress_index) if progress_index
  end

  # セクション1完了時: ユーザー機能関連ページ
  def capture_section_1_screenshots
    begin
      # 1. 新規登録ページ
      add_log("新規登録ページのスクリーンショットを撮影中...", :progress)
      driver.get("#{base_url}/users/sign_up")
      sleep 2
      capture_screenshot("signup_page", "Signup Page")
      remove_last_progress_log

      # 2. ログインページ
      add_log("ログインページのスクリーンショットを撮影中...", :progress)
      driver.get("#{base_url}/users/sign_in")
      sleep 2
      capture_screenshot("login_page", "Login Page")
      remove_last_progress_log

      # 3. トップページ（ログアウト状態）
      add_log("トップページ（ログアウト状態）のスクリーンショットを撮影中...", :progress)
      driver.get(base_url)
      sleep 2
      capture_screenshot("top_page_logout", "Top Page (Logout)")
      remove_last_progress_log

      # ログインして4. トップページ（ログイン状態）
      if @registered_users.any?
        login_with_registered_user
        add_log("トップページ（ログイン状態）のスクリーンショットを撮影中...", :progress)
        driver.get(base_url)
        sleep 2
        capture_screenshot("top_page_login", "Top Page (Login)")
        remove_last_progress_log
      end

    rescue => e
      add_log("! スクリーンショット撮影中にエラーが発生しました: #{e.message}", :error)
      Rails.logger.error "Screenshot capture error: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end

  # セクション2完了時: 投稿機能関連ページ
  def capture_section_2_screenshots
    begin
      # 新規投稿ページ
      add_log("新規投稿ページのスクリーンショットを撮影中...", :progress)
      driver.get("#{base_url}/prototypes/new")
      sleep 2
      capture_screenshot("prototype_new_page", "Prototype New Page")
      remove_last_progress_log

    rescue => e
      add_log("! スクリーンショット撮影中にエラーが発生しました: #{e.message}", :error)
      Rails.logger.error "Screenshot capture error: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end

  # セクション4完了時: プロトタイプ詳細ページ
  def capture_section_4_screenshots
    begin
      if @posted_prototype && @posted_prototype[:detail_url]
        # 前提: 4-003で別のユーザーでログイン状態で終了している

        # 1. 未ログイン状態（コメントフォームなし）
        add_log("プロトタイプ詳細ページ（未ログイン）のスクリーンショットを撮影中...", :progress)
        logout_if_needed
        driver.get(@posted_prototype[:detail_url])
        sleep 2
        capture_screenshot("prototype_detail_page_logout", "Prototype Detail Page (Logged Out)")
        remove_last_progress_log

        # 2. 投稿者本人でログイン（編集・削除ボタンあり、コメントフォームあり）
        add_log("プロトタイプ詳細ページ（投稿者）のスクリーンショットを撮影中...", :progress)
        login_with_registered_user
        driver.get(@posted_prototype[:detail_url])
        sleep 2
        capture_screenshot("prototype_detail_page_owner", "Prototype Detail Page (Owner)")
        remove_last_progress_log

        # 3. 別のユーザーでログイン（編集・削除ボタンなし、コメントフォームあり）
        if @registered_users.size >= 2
          add_log("プロトタイプ詳細ページ（他ユーザー）のスクリーンショットを撮影中...", :progress)
          logout_if_needed

          second_user = @registered_users[1]
          driver.get("#{base_url}/users/sign_in")
          sleep 2
          set_element_value_with_retry('user_email', second_user[:email])
          set_element_value_with_retry('user_password', second_user[:password])
          driver.find_element(:name, 'commit').click
          sleep 2

          driver.get(@posted_prototype[:detail_url])
          sleep 2
          capture_screenshot("prototype_detail_page_other_user", "Prototype Detail Page (Other User)")
          remove_last_progress_log
        end
      else
        add_log("! プロトタイプ詳細URLが見つかりません", :error)
      end
    rescue => e
      add_log("! スクリーンショット撮影中にエラーが発生しました: #{e.message}", :error)
      Rails.logger.error "Screenshot capture error: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end

  # セクション5完了時: プロトタイプ編集ページ
  def capture_section_5_screenshots
    begin
      if @posted_prototype && @posted_prototype[:edit_url]
        add_log("プロトタイプ編集ページのスクリーンショットを撮影中...", :progress)
        driver.get(@posted_prototype[:edit_url])
        sleep 2
        capture_screenshot("prototype_edit_page", "Prototype Edit Page")
        remove_last_progress_log
      else
        add_log("! プロトタイプ編集URLが見つかりません", :error)
      end
    rescue => e
      add_log("! スクリーンショット撮影中にエラーが発生しました: #{e.message}", :error)
      Rails.logger.error "Screenshot capture error: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end

  # セクション8完了時: ユーザー詳細ページ
  def capture_section_8_screenshots
    begin
      if @user_detail_url
        add_log("ユーザー詳細ページのスクリーンショットを撮影中...", :progress)
        driver.get(@user_detail_url)
        sleep 2
        capture_screenshot("user_detail_page", "User Detail Page")
        remove_last_progress_log
      else
        add_log("! ユーザー詳細URLが見つかりません", :error)
      end
    rescue => e
      add_log("! スクリーンショット撮影中にエラーが発生しました: #{e.message}", :error)
      Rails.logger.error "Screenshot capture error: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end

  # スクリーンショット撮影とセッションへの保存
  def capture_screenshot(filename_base, display_name)
    screenshots_dir = Rails.root.join('public', 'screenshots', 'pages')
    FileUtils.mkdir_p(screenshots_dir)

    filename = "#{filename_base}_#{@screenshot_timestamp}.png"
    filepath = screenshots_dir.join(filename).to_s
    take_full_page_screenshot(filepath)

    screenshot_info = {
      name: display_name,
      filename: filename,
      path: "/screenshots/pages/#{filename}"
    }

    @screenshots << screenshot_info

    # セッションに即座にスクリーンショット情報を追加
    if @sessions_store && @session_id && @sessions_store[@session_id]
      @sessions_store[@session_id][:screenshots] ||= []
      @sessions_store[@session_id][:screenshots] << screenshot_info
    end
  end

  def cleanup
    @driver.quit if @driver
  rescue => e
    Rails.logger.error "Driver cleanup error: #{e.message}"
  end

  def ensure_chrome_environment
    chrome_path = '/tmp/chrome-linux64/chrome'
    driver_path = '/tmp/chromedriver-linux64/chromedriver'

    # すでに存在するならスキップ
    return if File.exist?(chrome_path) && File.exist?(driver_path)

    # /tmpを用意
    FileUtils.mkdir_p('/tmp/chrome-linux64')
    FileUtils.mkdir_p('/tmp/chromedriver-linux64')

    # Chrome本体
    unless File.exist?(chrome_path)
      system("wget -q https://storage.googleapis.com/chrome-for-testing-public/131.0.6778.108/linux64/chrome-linux64.zip -O /tmp/chrome.zip")
      system("unzip -q /tmp/chrome.zip -d /tmp/")
      system("chmod +x #{chrome_path}")
    end

    # ChromeDriver
    unless File.exist?(driver_path)
      system("wget -q https://storage.googleapis.com/chrome-for-testing-public/131.0.6778.108/linux64/chromedriver-linux64.zip -O /tmp/chromedriver.zip")
      system("unzip -q /tmp/chromedriver.zip -d /tmp/")
      system("chmod +x #{driver_path}")
    end
  end

end
