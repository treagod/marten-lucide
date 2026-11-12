class HomeHandler < Marten::Handlers::Template
  template_name "home.html"

  def get
    render_to_response({icons: %w[house search bookmark settings triangle-alert]})
  end
end
