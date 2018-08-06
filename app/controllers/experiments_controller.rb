class ExperimentsController < ApplicationController
  before_action :authenticate_admin, except: [:metatags, :redirect, :lookup, :preview_image]
  before_action :set_experiment
  before_action :check_for_key_param, only: [:metatags, :redirect]

  def index
    @experiments = Experiment.all
  end

  def new
    @experiment = Experiment.new
  end

  def create
    experiment = Experiment.create!(experiment_params)
    redirect_to edit_experiment_path(experiment)
  end

  def edit
    @experiment_props = data_for_experiment
  end

  def update
    @experiment.update_attributes(experiment_params.to_h)
    render json: data_for_experiment
  end

  def results
    @experiment_props = { experiment: @experiment.results }
  end

  def demo
  end

  def metatags
    @share = @experiment.get_share_by_key(params[:key], params[:v], params[:r])
    @metatags = @share.variant.render_metatags(params)
    render layout: false
  end

  def preview_image
    variant = Variant.find(params[:v])

    respond_to do |format|
      format.jpg do
        send_data(variant.render_to_jpg(params).to_blob, :type => "image/jpg", :disposition => 'inline')
      end
    end
  end

  def redirect
    click_key = Click.generate_key
    AddClickWorker.perform_async(params[:key], click_key, request.user_agent, request.remote_ip)
    Rails.logger.info(request.user_agent)
    Rails.logger.info(request.headers)
    redirect_to("https://#{@experiment.url}?rkey=#{click_key}&utm_source=share&utm_medium=facebook&utm_campaign=#{params[:key]}")
  end

  private

  def experiment_params
    raw_params = params.require(:experiment).permit(:id, :name, :url, variants: [:id, :title, :description, :image_url, :_destroy, overlays: [:text, :top, :left, :size, :color, :font, :textStrokeWidth, :textStrokeColor, :align]])
    raw_params[:variants_attributes] = raw_params[:variants] if raw_params[:variants].present?
    raw_params.delete(:variants)
    raw_params
  end

  def set_experiment
    @experiment = Experiment.find(params[:id]) if params[:id].present?
  end

  def check_for_key_param
    unless params[:key].present?
      redirect_to("https://#{@experiment.url}")
    end
  end

  def data_for_experiment
    data = @experiment.as_json(include: :variants)
    data['variants'] = data['variants'].sort_by{ |o| o['id'] }.map do |v|
      if v['overlays'].present?
        v['overlays'] = v['overlays'].map do |k, overlay|
          overlay['size'] = overlay['size'].to_i
          overlay['top'] = overlay['top'].to_i
          overlay['left'] = overlay['left'].to_i
          overlay['textStrokeWidth'] = overlay['textStrokeWidth'].to_i
          overlay
        end
      end
      v
    end

    { experiment: data , unsavedChanges: false }
  end
end
