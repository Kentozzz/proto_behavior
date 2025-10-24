class ProtospaceCheckerService
  attr_reader :driver, :base_url, :results, :logs, :registered_users

  def initialize(target_url, &log_callback)
    @base_url = target_url.gsub(/\/+$/, '')
    @results = []
    @logs = []
    @registered_users = []
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

    # 1-013〜1-017、2-001: 同じブラウザセッションで実行
    setup_driver
    run_check_1_013(cleanup_logs: false)
    run_check_1_014(cleanup_logs: false)
    run_check_1_015(cleanup_logs: false)
    run_check_1_016(cleanup_logs: false)
    run_check_1_017(cleanup_logs: false)
    run_check_2_001(cleanup_logs: false)

    # 1-018: パスワード一致チェック
    setup_driver
    run_check_1_018(cleanup_logs: false)

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
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-gpu')
    options.add_argument('--disable-software-rasterizer')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-web-security')
    options.add_argument('--single-process')
    options.add_argument("--user-data-dir=/tmp/chrome-test-#{Time.now.to_i}-#{rand(10000)}")
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
end
