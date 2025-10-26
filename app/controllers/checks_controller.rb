class ChecksController < ApplicationController
  # セッションごとの実行状態を保持するクラス変数
  @@check_sessions = {}

  def index
    # 全セッションから登録済みユーザーを取得
    @all_registered_users = []
    @@check_sessions.each do |session_id, session_data|
      if session_data[:registered_users]
        @all_registered_users += session_data[:registered_users]
      end
    end

    # 実行中のセッションを検出
    @running_session = @@check_sessions.find { |_id, data| data[:status] == 'running' }
    @is_running = @running_session.present?
  end

  def new
  end

  def create
    target_url = params[:target_url]
    session_id = SecureRandom.uuid

    # セッションデータを初期化
    @@check_sessions[session_id] = {
      status: 'running',
      logs: [],
      results: [],
      screenshots: [],
      target_url: target_url,
      cancelled: false
    }

    # バックグラウンドでチェックを実行
    thread = Thread.new do
      begin
        checker = ProtospaceCheckerService.new(target_url, session_id: session_id, sessions_store: @@check_sessions) do |log_entry|
          # ログが追加されるたびにセッションに保存
          if @@check_sessions[session_id]
            # progressタイプのログは最後のprogressログを置き換え
            if log_entry[:type] == :progress
              # 最後のログがprogressなら置き換え、そうでなければ追加
              if @@check_sessions[session_id][:logs].last && @@check_sessions[session_id][:logs].last[:type] == :progress
                @@check_sessions[session_id][:logs][-1] = log_entry
              else
                @@check_sessions[session_id][:logs] << log_entry
              end
            # success/fail/errorログは最後のcheck_startログを置き換え
            elsif [:success, :fail, :error].include?(log_entry[:type])
              check_start_index = @@check_sessions[session_id][:logs].rindex { |log| log[:type] == :check_start }
              if check_start_index
                # check_start以降のprogressログを削除
                @@check_sessions[session_id][:logs].delete_if.with_index { |log, index| index > check_start_index && log[:type] == :progress }
                # check_startログを置き換え
                check_start_index = @@check_sessions[session_id][:logs].rindex { |log| log[:type] == :check_start }
                @@check_sessions[session_id][:logs][check_start_index] = log_entry
              else
                @@check_sessions[session_id][:logs] << log_entry
              end
            # check_startログの前のprogressログを削除
            elsif log_entry[:type] == :check_start
              # 最後のログがprogressなら削除
              if @@check_sessions[session_id][:logs].last && @@check_sessions[session_id][:logs].last[:type] == :progress
                @@check_sessions[session_id][:logs].pop
              end
              @@check_sessions[session_id][:logs] << log_entry
            else
              @@check_sessions[session_id][:logs] << log_entry
            end
          end
        end

        data = checker.run_all_checks

        if @@check_sessions[session_id]
          @@check_sessions[session_id][:results] = data[:results]
          @@check_sessions[session_id][:logs] = data[:logs]
          @@check_sessions[session_id][:registered_users] = data[:registered_users]
          @@check_sessions[session_id][:screenshots] = data[:screenshots] || []
          @@check_sessions[session_id][:failure_screenshots] = data[:failure_screenshots] || []
          @@check_sessions[session_id][:status] = 'completed'
        end
      rescue => e
        if @@check_sessions[session_id]
          @@check_sessions[session_id][:logs] << "エラー: #{e.message}"
          @@check_sessions[session_id][:status] = 'error'
        end
      end
    end

    # スレッドをセッションに保存
    @@check_sessions[session_id][:thread] = thread

    # 結果ページにリダイレクト（session_idを渡す）
    redirect_to check_status_path(session_id)
  end

  def status
    session_id = params[:id]
    @session_data = @@check_sessions[session_id]

    if @session_data.nil?
      redirect_to checks_path, alert: 'セッションが見つかりません'
      return
    end

    @results = @session_data[:results]
    @logs = @session_data[:logs]
    @status = @session_data[:status]
    @registered_users = @session_data[:registered_users] || []
    @screenshots = @session_data[:screenshots] || []
    @failure_screenshots = @session_data[:failure_screenshots] || []
    @session_id = session_id

    # 実行中のセッションを検出
    @running_session = @@check_sessions.find { |_id, data| data[:status] == 'running' }
    @is_running = @running_session.present?

    render :result
  end

  def poll
    session_id = params[:id]
    session_data = @@check_sessions[session_id]

    if session_data.nil?
      render json: { error: 'Session not found' }, status: :not_found
      return
    end

    render json: {
      status: session_data[:status],
      logs: session_data[:logs],
      results: session_data[:results],
      registered_users: session_data[:registered_users] || [],
      screenshots: session_data[:screenshots] || [],
      failure_screenshots: session_data[:failure_screenshots] || []
    }
  end

  def cancel
    # 現在実行中のセッションを探す
    running_session = @@check_sessions.find { |_id, data| data[:status] == 'running' }

    if running_session
      session_id, session_data = running_session

      # キャンセルフラグを立てる
      session_data[:cancelled] = true
      session_data[:status] = 'cancelled'

      # プログレスログを削除
      session_data[:logs].reject! { |log| log[:type] == :progress }

      session_data[:logs] << { message: "テストが中止されました", type: :error }

      # スレッドが保存されていれば終了させる
      if session_data[:thread]
        session_data[:thread].kill
      end

      redirect_to check_status_path(session_id), notice: 'テストを中止しました'
    else
      redirect_to checks_path, alert: '実行中のテストがありません'
    end
  end
end
