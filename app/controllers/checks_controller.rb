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
      target_url: target_url
    }

    # バックグラウンドでチェックを実行
    Thread.new do
      begin
        checker = ProtospaceCheckerService.new(target_url) do |log_entry|
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
          @@check_sessions[session_id][:status] = 'completed'
        end
      rescue => e
        if @@check_sessions[session_id]
          @@check_sessions[session_id][:logs] << "エラー: #{e.message}"
          @@check_sessions[session_id][:status] = 'error'
        end
      end
    end

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
    @session_id = session_id

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
      registered_users: session_data[:registered_users] || []
    }
  end
end
