class ProtospaceCheckerService
  attr_reader :driver, :base_url, :results, :logs, :registered_users, :posted_prototype

  def initialize(target_url, &log_callback)
    @base_url = target_url.gsub(/\/+$/, '')
    @results = []
    @logs = []
    @registered_users = []
    @posted_prototype = {}
    @log_callback = log_callback
    setup_driver
  end

  def run_all_checks
    add_log("全チェックを開始します", :info)

    # バリデーションチェック（1-001 ~ 1-010）
    run_validation_checks

    # 1-011: ユーザー新規登録
    setup_driver
    run_check_1_011(cleanup_logs: false)

    # 1-012: ログインフォーム空欄チェック
    setup_driver
    run_check_1_012(cleanup_logs: false)

    # 1-013〜1-017: 同じブラウザセッションで実行
    setup_driver
    run_check_1_013(cleanup_logs: false)
    run_check_1_014(cleanup_logs: false)
    run_check_1_015(cleanup_logs: false)
    run_check_1_016(cleanup_logs: false)
    run_check_1_017(cleanup_logs: false)

    # 1-018: パスワード一致チェック
    setup_driver
    run_check_1_018(cleanup_logs: false)

    # 2-001〜2-006: 投稿ページ遷移とバリデーションチェック（同じセッション）
    setup_driver
    run_check_2_001(cleanup_logs: false)
    run_prototype_validation_checks

    # 2-007〜2-009: 正常投稿とトップページ表示確認
    setup_driver
    run_check_2_007(cleanup_logs: false)

    # 3-001〜3-003: プロトタイプ一覧表示機能（同じセッション）
    run_check_3_001(cleanup_logs: false)
    run_check_3_002_and_3_003(cleanup_logs: false)

    # 4-001〜4-003: プロトタイプ詳細表示機能（同じセッション）
    run_check_4_001_4_002_4_003(cleanup_logs: false)

    # 最後にクリーンアップとログ整理
    cleanup
    add_log("全チェック完了", :info)
    @logs.reject! { |log| log[:type] == :progress }

    { results: results, logs: logs, registered_users: registered_users }
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
      add_log("テストユーザーを登録中...", :progress)
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
        name: test_data[:name]
      }

      # ログアウト
      add_log("ログアウト中...", :progress)
      driver.get(base_url)
      sleep 1
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 1
      rescue
        # ログアウトリンクがない場合はスキップ
      end

      # 同じメールアドレスで再登録を試行
      add_log("同じメールアドレスで再登録を試行中...", :progress)
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
      add_log("@を含まないメールアドレスで登録を試行中...", :progress)

      test_data = base_data.dup
      test_data[:email] = "invalidemail.com"

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
      add_log("5文字のパスワードで登録を試行中...", :progress)

      test_data = base_data.dup
      test_data[:password] = "12345"
      test_data[:password_confirmation] = "12345"

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
      add_log("パスワード確認を空にして登録を試行中...", :progress)

      test_data = base_data.dup
      test_data[:password_confirmation] = ""

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
        add_result(check_number, description, "FAIL", "パスワード確認なしで登録できてしまいます")
      end
    rescue => e
      add_log("! エラー発生: #{e.message}", :error)
      add_result(check_number, description, "ERROR", e.message)
    end
  end

  def fill_signup_form(data)
    driver.execute_script("document.getElementById('user_email').value = '#{data[:email]}';")
    driver.execute_script("document.getElementById('user_password').value = '#{data[:password]}';")
    driver.execute_script("document.getElementById('user_password_confirmation').value = '#{data[:password_confirmation]}';")
    driver.execute_script("document.getElementById('user_name').value = '#{data[:name]}';")
    driver.execute_script("document.getElementById('user_profile').value = '#{data[:profile]}';")
    driver.execute_script("document.getElementById('user_occupation').value = '#{data[:occupation]}';")
    driver.execute_script("document.getElementById('user_position').value = '#{data[:position]}';")
  end

  def setup_driver
    ensure_chrome_environment
    cleanup if @driver

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--disable-software-rasterizer')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-web-security')
    options.add_argument('--disable-setuid-sandbox')  # ← 追加！
    options.add_argument('--remote-debugging-port=9222') # ← 追加！
    options.add_argument('--window-size=1280,720')
    options.add_argument('--user-data-dir=/tmp/user-data') # ← 追加！
    options.add_argument('--data-path=/tmp/data-path')     # ← 追加！
    options.add_argument('--disk-cache-dir=/tmp/cache-dir') # ← 追加！
    options.add_argument('--remote-debugging-address=0.0.0.0') # ← 安定化
    options.binary = '/tmp/chrome-linux64/chrome'

    Selenium::WebDriver::Chrome::Service.driver_path = '/tmp/chromedriver-linux64/chromedriver'
    @driver = Selenium::WebDriver.for :chrome, options: options
    @driver.manage.window.resize_to(1280, 720)
  end

  def run_check_1_011(cleanup_logs: true)
    begin
      add_log("　 1-011: 必須項目に適切な値を入力すると、ユーザーの新規登録ができること", :check_start)

      # テストユーザーを作成
      test_email = "signup-test-#{Time.now.to_i}@example.com"
      test_password = "aaa111"

      # 新規登録ページに移動
      add_log("新規登録ページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_up")
      sleep 2

      # フォームに入力
      add_log("必須項目を入力中...", :progress)
      driver.execute_script("document.getElementById('user_email').value = '#{test_email}';")
      driver.execute_script("document.getElementById('user_password').value = '#{test_password}';")
      driver.execute_script("document.getElementById('user_password_confirmation').value = '#{test_password}';")
      driver.execute_script("document.getElementById('user_name').value = 'テストユーザー';")
      driver.execute_script("document.getElementById('user_profile').value = 'テストプロフィール';")
      driver.execute_script("document.getElementById('user_occupation').value = 'テスト会社';")
      driver.execute_script("document.getElementById('user_position').value = 'テスト役職';")

      # 登録ボタンをクリック
      add_log("ユーザー登録を実行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 3

      # トップページに遷移したか確認
      add_log("登録結果を確認中...", :progress)
      current_url = driver.current_url
      is_top_page = (current_url == base_url || current_url == "#{base_url}/")

      if is_top_page
        add_log("✓ 1-011: 必須項目に適切な値を入力すると、ユーザーの新規登録ができること", :success)
        add_result("1-011", "必須項目に適切な値を入力すると、ユーザーの新規登録ができること", "PASS", "")

        # 登録したユーザー情報を保存
        @registered_users << {
          email: test_email,
          password: test_password,
          name: "テストユーザー"
        }
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
      add_log("ログインページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      # フォームに何も入力せずにログインボタンをクリック
      add_log("空欄のままログインを試行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 2

      # ログインページに留まっているか確認（トップページに遷移していないことを確認）
      add_log("ログイン結果を確認中...", :progress)
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
      driver.execute_script("document.getElementById('user_email').value = '#{test_email}';")
      driver.execute_script("document.getElementById('user_password').value = '#{test_password}';")

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
      add_log("ログアウトリンクを探しています...", :progress)
      driver.get(base_url)
      sleep 1

      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        add_log("ログアウト実行中...", :progress)
        logout_link.click
        sleep 2

        # ログアウトできたか確認（ログアウト後はログインページやトップページに遷移）
        add_log("ログアウト結果を確認中...", :progress)
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
      add_log("ログインページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      # ログイン情報を入力
      add_log("ログイン情報を入力中...", :progress)
      driver.execute_script("document.getElementById('user_email').value = '#{test_email}';")
      driver.execute_script("document.getElementById('user_password').value = '#{test_password}';")

      # ログインボタンをクリック
      add_log("ログイン実行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 3

      # トップページでヘッダーリンクを確認
      add_log("ヘッダーリンクを確認中...", :progress)
      driver.get(base_url)
      sleep 1

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
      add_log("ユーザー名表示を確認中...", :progress)
      driver.get(base_url)
      sleep 1

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
      add_log("ログアウト処理中...", :progress)
      driver.get(base_url)
      sleep 1
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 2
      rescue
        # ログアウトリンクがない場合はスキップ
      end

      # トップページでヘッダーリンクを確認
      add_log("ヘッダーリンクを確認中...", :progress)
      driver.get(base_url)
      sleep 1

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
      add_log("新規登録ページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_up")
      sleep 2

      # フォームに入力（確認用パスワードだけ異なる値）
      add_log("全項目を入力中...", :progress)
      driver.execute_script("document.getElementById('user_email').value = '#{test_email}';")
      driver.execute_script("document.getElementById('user_password').value = 'aaa111';")
      driver.execute_script("document.getElementById('user_password_confirmation').value = 'iii222';")
      driver.execute_script("document.getElementById('user_name').value = 'パスワード不一致テスト';")
      driver.execute_script("document.getElementById('user_profile').value = 'テストプロフィール';")
      driver.execute_script("document.getElementById('user_occupation').value = 'テスト会社';")
      driver.execute_script("document.getElementById('user_position').value = 'テスト役職';")

      # 登録ボタンをクリック
      add_log("登録を試行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 2

      # 登録ページに留まっているか確認
      add_log("登録結果を確認中...", :progress)
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
      add_log("ログアウト状態で新規投稿ページへのアクセスを試行中...", :progress)
      driver.get("#{base_url}/prototypes/new")
      sleep 2

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
      add_log("ログインページへ移動中...", :progress)
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      # ログイン情報を入力
      add_log("ログイン情報を入力中...", :progress)
      driver.execute_script("document.getElementById('user_email').value = '#{test_email}';")
      driver.execute_script("document.getElementById('user_password').value = '#{test_password}';")

      # ログインボタンをクリック
      add_log("ログイン実行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 3

      # トップページに移動して「New Proto」リンクをクリック
      add_log("「New Proto」リンクをクリック中...", :progress)
      driver.get(base_url)
      sleep 1

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
      add_log("#{field}を空にして投稿を試行中...", :progress)

      test_data = base_data.dup
      test_data[field] = invalid_value

      driver.get("#{base_url}/prototypes/new")
      sleep 1

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
      add_log("画像なしで投稿を試行中...", :progress)

      test_data = base_data.dup
      test_data[:image] = nil

      driver.get("#{base_url}/prototypes/new")
      sleep 1

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
      add_log("すべて空欄で投稿を試行中...", :progress)

      driver.get("#{base_url}/prototypes/new")
      sleep 1

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
      add_log("投稿ページへ移動中...", :progress)
      driver.get("#{base_url}/prototypes/new")
      sleep 2

      # フォームに入力
      add_log("必要な情報を入力中...", :progress)
      fill_prototype_form({
        title: test_title,
        catch_copy: test_catch_copy,
        concept: test_concept,
        image: ensure_test_image
      })

      # 投稿ボタンをクリック
      add_log("投稿実行中...", :progress)
      driver.find_element(:name, 'commit').click
      sleep 3

      # 2-008: トップページに遷移したか確認
      add_log("投稿結果を確認中...", :progress)
      current_url = driver.current_url
      is_top_page = (current_url == base_url || current_url == "#{base_url}/")

      if is_top_page
        add_log("✓ 2-007: 必要な情報を入力すると、投稿ができること", :success)
        add_result("2-007", "必要な情報を入力すると、投稿ができること", "PASS", "")

        add_log("✓ 2-008: 正しく投稿できた場合は、トップページへ遷移すること", :success)
        add_result("2-008", "正しく投稿できた場合は、トップページへ遷移すること", "PASS", "")

        # 2-009: 投稿した情報がトップページに表示されているか確認
        add_log("　 2-009: 投稿した情報は、トップページに表示されること", :check_start)
        add_log("投稿内容の表示を確認中...", :progress)
        sleep 1

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
      add_log("ログアウト状態で一覧表示を確認中...", :progress)
      driver.get(base_url)
      sleep 1

      # ログアウトリンクがあればログアウト
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 1
      rescue
        # 既にログアウト状態
      end

      driver.get(base_url)
      sleep 1

      # 投稿したプロトタイプが表示されているか確認
      page_text = driver.find_element(:tag_name, 'body').text
      logout_can_view = page_text.include?(@posted_prototype[:title])

      # パート2: ログイン状態で一覧閲覧
      add_log("ログイン状態で一覧表示を確認中...", :progress)
      login_with_registered_user
      driver.get(base_url)
      sleep 1

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
    begin
      # チェック番号1: 4つの情報表示確認
      add_log("　 チェック番号1: プロトタイプ毎に、画像・プロトタイプ名・キャッチコピー・投稿者名の、4つの情報について表示できること", :check_start)
      add_log("4つの情報の表示を確認中...", :progress)

      driver.get(base_url)
      sleep 1

      page_source = driver.page_source
      page_text = driver.find_element(:tag_name, 'body').text

      # 画像の存在確認
      has_image = false
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

      # 3-002: 画像表示とリンク切れチェック
      add_log("　 3-002: 画像が表示されており、画像がリンク切れなどになっていないこと", :check_start)
      add_log("画像のリンク切れを確認中...", :progress)

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

      # 3-003: 詳細ページ遷移確認
      add_log("　 3-003: ログイン・ログアウトの状態に関わらず、一覧表示されている画像およびプロトタイプ名をクリックすると、該当するプロトタイプの詳細ページへ遷移すること", :check_start)

      # パート1: ログアウト状態で詳細ページ遷移確認
      add_log("ログアウト状態で詳細ページへの遷移を確認中...", :progress)

      # ログアウト
      driver.get(base_url)
      sleep 1
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 1
      rescue
        # 既にログアウト状態
      end

      driver.get(base_url)
      sleep 1

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
      add_log("ログイン状態で詳細ページへの遷移を確認中...", :progress)

      login_with_registered_user
      driver.get(base_url)
      sleep 1

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
      add_result("3-002/3-003", "一覧表示機能テスト", "ERROR", e.message)
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
        add_log("詳細ページへ遷移中...", :progress)
        driver.get(base_url)
        sleep 1

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

      # ===== パート1: ログアウト状態での確認 =====
      add_log("ログアウト状態での詳細ページを確認中...", :progress)

      # ログアウト
      driver.get(base_url)
      sleep 1
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 1
      rescue
        # 既にログアウト状態
      end

      # 詳細ページに遷移
      driver.get(detail_url)
      sleep 2

      page_text = driver.find_element(:tag_name, 'body').text
      page_source = driver.page_source

      # 4-001 (ログアウト): 編集・削除リンクが存在しないこと
      logout_has_edit = page_text.include?('編集') && (page_source.include?('/edit') || page_source.include?('edit'))
      logout_has_delete = page_text.include?('削除') && (page_source.include?('delete') || page_source.include?('destroy'))

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
      add_log("投稿者でログイン状態での詳細ページを確認中...", :progress)

      login_with_registered_user
      driver.get(detail_url)
      sleep 2

      page_text = driver.find_element(:tag_name, 'body').text
      page_source = driver.page_source

      # 4-001 (投稿者): 編集・削除リンクが存在すること
      owner_has_edit = page_text.include?('編集') && (page_source.include?('/edit') || page_source.include?('edit'))
      owner_has_delete = page_text.include?('削除') && (page_source.include?('delete') || page_source.include?('destroy'))

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
      add_log("別のユーザーでログイン中...", :progress)

      # ログアウト
      driver.get(base_url)
      sleep 1
      begin
        logout_link = driver.find_element(:link_text, 'ログアウト')
        logout_link.click
        sleep 1
      rescue
      end

      # 既存の2人目のユーザーを使用（セクション1で登録済み）
      if @registered_users.length >= 2
        other_user = @registered_users[1]
      else
        raise "別のユーザーが登録されていません。@registered_usersに2人以上のユーザーが必要です。"
      end

      # 2人目のユーザーでログイン
      driver.get("#{base_url}/users/sign_in")
      sleep 2

      driver.execute_script("document.getElementById('user_email').value = '#{other_user[:email]}';")
      driver.execute_script("document.getElementById('user_password').value = '#{other_user[:password]}';")
      driver.find_element(:name, 'commit').click
      sleep 2

      add_log("別のユーザーでログイン状態での詳細ページを確認中...", :progress)

      driver.get(detail_url)
      sleep 2

      page_text = driver.find_element(:tag_name, 'body').text
      page_source = driver.page_source

      # 4-001 (別ユーザー): 編集・削除リンクが存在しないこと
      other_has_edit = page_text.include?('編集') && (page_source.include?('/edit') || page_source.include?('edit'))
      other_has_delete = page_text.include?('削除') && (page_source.include?('delete') || page_source.include?('destroy'))

      # ===== 4-001の結果判定 =====
      add_log("　 4-001: ログイン状態の投稿したユーザーだけに、「編集」「削除」のリンクが存在すること", :check_start)

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

      # ===== 4-002の結果判定 =====
      add_log("　 4-002: ログイン・ログアウトの状態に関わらず、プロダクトの情報（プロトタイプ名・投稿者・画像・キャッチコピー・コンセプト）が表示されていること", :check_start)

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

      # 詳細ページに再度アクセスして画像を確認
      driver.get(detail_url)
      sleep 2

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

  def fill_prototype_form(data)
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
    return if @registered_users.empty?

    test_user = @registered_users.first
    driver.get("#{base_url}/users/sign_in")
    sleep 1

    driver.execute_script("document.getElementById('user_email').value = '#{test_user[:email]}';")
    driver.execute_script("document.getElementById('user_password').value = '#{test_user[:password]}';")
    driver.find_element(:name, 'commit').click
    sleep 2
  end

  def ensure_test_image
    # ユーザーが用意したsakura.jpgを優先的に使用
    sakura_path = '/tmp/sakura.jpg'
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

  def add_result(check_number, description, status, note)
    results << {
      check_number: check_number,
      description: description,
      status: status,
      note: note
    }
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
