require_dependency "translation_center/application_controller"

module TranslationCenter
  class TranslationKeysController < ApplicationController
    before_filter :get_translation_key, except: [ :search ]
    before_filter :can_admin?, only: [ :destroy, :update ]

    # POST /translation_keys/1/update_translation.js
    def update_translation
      @translation = current_user.translation_for @translation_key, session[:lang_to]
      @key_before_status = @translation_key.status(session[:lang_to])
      respond_to do |format|
        # only admin can edit accepted translations
        if (current_user.can_admin_translations? || !@translation.accepted?) && !trans_params[:value].strip.blank?
          # use yaml.load to handle arrays
          @translation.update_attributes(value: YAML.load(trans_params[:value].strip), status: 'pending')
          # translation added by admin is considered the accepted one as it is trusted
          @translation.accept if current_user.can_admin_translations? && CONFIG['accept_admin_translations']
          format.json {render json: { value: @translation.value, status: @translation.key.status(@translation.lang), key_before_status: @key_before_status  } }
        else
          render nothing: true
        end 
      end
    end

    # GET /translation_keys/translations
    def translations
      @translations = @translation_key.translations.in(session[:lang_to]).order('created_at DESC')
      
      respond_to do |format|
        format.js
      end
    end

    # GET /translation_keys/1
    def show
    end
    
    # PUT /translation_keys/1
    # PUT /translation_keys/1.json
    def update
      trans_params[:value].strip!
      @old_value = @translation_key.category.name
      respond_to do |format|
        if !trans_params[:value].blank? && @translation_key.update_attribute(:name, trans_params[:value])
          format.json { render json: {  new_value: @translation_key.name, new_category: @translation_key.category.name, old_category: @old_value, key_id: @translation_key.id } }
        else
          format.json { render json: @translation_key.errors, status: :unprocessable_entity }
        end
      end
    end
  
    # DELETE /translation_keys/1
    # DELETE /translation_keys/1.json
    def destroy
      @category = @translation_key.category
      @translation_key_id = @translation_key.id
      @key_status = @translation_key.status(session[:lang_to])
      @translation_key.destroy
  
      respond_to do |format|
        format.js
        format.html {redirect_to @category, notice: I18n.t('translation_center.translation_keys.destroyed_successfully')}
      end
    end

    # GET /translation_keys/search.json
    def search
      # if full name provided then get the key and redirect to it, otherwise return similar in json
      if trans_params[:search_key_name].present?
        @translation_key = TranslationKey.find_by_name(trans_params[:search_key_name])
      else
        @key_names = TranslationKey.where('name LIKE ?', "%#{trans_params[:query]}%")
      end

      respond_to do |format|
        format.html { redirect_to @translation_key}
        format.json { render json: @key_names.map(&:name) }
      end
    end

    protected

    def get_translation_key
      id = trans_params[:translation_key_id] || trans_params[:id]
      @translation_key = TranslationKey.find(id)
    end
    
    def trans_params
      params.permit!
    end
  end
end
