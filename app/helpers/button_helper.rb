module ButtonHelper
  # Output a "Copy to Clipboard" button
  #
  # data      - Data attributes passed to `content_tag` (default: {})
  # css_class - CSS class override (default: "btn-clipboard")
  #
  # Examples:
  #
  #   # Define the clipboard's text
  #   clipboard_button(data: { clipboard_text: "Foo" })
  #   # => "<button class='...' data-clipboard-text='Foo'>...</button>"
  #
  #   # Define the target element
  #   clipboard_button(data: { clipboard_target: "div#foo" })
  #   # => "<button class='...' data-clipboard-target='div#foo'>...</button>"
  #
  #   # Override the CSS class
  #   clipboard_button(css_class: 'btn-transparent')
  #   # => "<button class='btn btn-transparent'>...</button>"
  #
  # See http://clipboardjs.com/#usage
  def clipboard_button(data: {}, css_class: 'btn-clipboard')
    content_tag :button,
      icon('clipboard'),
      class: "btn #{css_class}",
      data: data,
      type: :button
  end

  def http_clone_button(project, placement = 'right', append_link: true)
    klass = 'http-selector'
    klass << ' has-tooltip' if current_user.try(:require_password?)

    protocol = gitlab_config.protocol.upcase

    content_tag (append_link ? :a : :span), protocol,
      class: klass,
      href: (project.http_url_to_repo if append_link),
      data: {
        html: true,
        placement: placement,
        container: 'body',
        title: "Set a password on your account<br>to pull or push via #{protocol}"
      }
  end

  def ssh_clone_button(project, placement = 'right', append_link: true)
    klass = 'ssh-selector'
    klass << ' has-tooltip' if current_user.try(:require_ssh_key?)

    content_tag (append_link ? :a : :span), 'SSH',
      class: klass,
      href: (project.ssh_url_to_repo if append_link),
      data: {
        html: true,
        placement: placement,
        container: 'body',
        title: 'Add an SSH key to your profile<br>to pull or push via SSH.'
      }
  end
end
