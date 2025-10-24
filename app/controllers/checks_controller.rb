class ChecksController < ApplicationController
  def index
    @check_sessions = CheckSession.order(created_at: :desc).limit(10)
  end

  def new
  end

  def create
    @check_session = CheckSession.create!(
      target_url: params[:target_url],
      status: 'running',
      started_at: Time.current
    )

    # 同期的にチェックを実行（簡易版）
    ProtospaceCheckerService.new(@check_session).run_check_1_013

    redirect_to check_path(@check_session), notice: 'チェックが完了しました'
  end

  def show
    @check_session = CheckSession.find(params[:id])
    @check_results = @check_session.check_results.order(:section_number, :check_number)
  end
end
