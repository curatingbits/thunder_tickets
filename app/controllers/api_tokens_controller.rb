# Revoking a workstation token from Settings. Tokens are only ever created
# from the command line (bin/rails api_tokens:create), so none is ever shown
# in a page.
class ApiTokensController < ApplicationController
  def destroy
    token = ApiToken.find(params[:id])
    token.revoke!
    redirect_to settings_path, notice: "Revoked #{token.name}."
  end
end
