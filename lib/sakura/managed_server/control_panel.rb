
require 'uri'
require 'mechanize'
require 'logger'

module Sakura::ManagedServer
  class ControlPanel
    URL_LOGIN = URI.parse("https://secure.sakura.ad.jp/rscontrol/")
    URL_PANEL_TOP = URI.parse("https://secure.sakura.ad.jp/rscontrol/ms/")

    class LoginFailure < StandardError
    end

    def initialize(domain, password)
      @domain = domain
      @password = password

      login
    end

    def login(domain = @domain, password = @password)
      @domain = domain
      @password = password
      @agent = Mechanize.new{|a| a.log = Logger.new("mechanize.log")}

      page = @agent.get(URL_LOGIN)
      login_form = page.form_with(:name => "login")
      login_form.field_with(:name => "domain").value = domain
      login_form.field_with(:name => "password").value = password
      login_result = @agent.submit(login_form)

      if login_result.uri == URL_LOGIN
        raise LoginFailure.new("Domain: #{domain}")
      end

      true
    end

    def get_users
      page = page_user
      page.parser.search("table[@class='viewbox'][@width='500']").search("tr/td[1]/b/font").map(&:inner_text)
    end

    def add_user(username, password,
                 config = {
                   :comment => "",
                   :use_mail => true,
                   :use_ftp => false,
                   :use_file_sharing => false,
                   :mail_quota => 200, # in MB
                   :virus_check => false,
                   :spam_filter => false
                 })
      page = page_usermanage
      form = page.form_with(:name => "userform")

      form.field_with(:name => "Username").value = username
      form.field_with(:name => "Comment").value = config[:comment]
      form.field_with(:name => "Password1").value = password
      form.field_with(:name => "Password2").value = password

      if config[:use_mail]
        form.checkbox_with(:name => "Mail").check
      else
        form.checkbox_with(:name => "Mail").uncheck
      end
      if config[:use_ftp]
        form.checkbox_with(:name => "Web").check
      else
        form.checkbox_with(:name => "Web").uncheck
      end
      if config[:use_file_sharing]
        form.checkbox_with(:name => "WebDAV").check
      else
        form.checkbox_with(:name => "WebDAV").uncheck
      end

      form.field_with(:name => "MailQuota").value = config[:mail_quota]
      if config[:virus_check]
        form.radiobuttons_with(:name => "VirusScan")[1].check
      else
        form.radiobuttons_with(:name => "VirusScan")[0].check
      end
      if config[:spam_filter]
        form.radiobuttons_with(:name => "SpamFilter")[1].check
      else
        form.radiobuttons_with(:name => "SpamFilter")[0].check
      end

      result_page = @agent.submit(form, form.button_with(:name => "Submit_usermanage"))

      if result_page.uri == URL_PANEL_TOP + "user"
        username
      else
        false
      end
    end

    def logged_in?
      page = get(URL_PANEL_TOP)
      page.uri == URL_PANEL_TOP
    end

    def get(url)
      @agent.get(url)
    end

    def get_panel_page(rel_path)
      if ! logged_in?
        login
      end

      get(URL_PANEL_TOP + rel_path)
    end

    def page_user
      get_panel_page("user")
    end
    def page_usermanage
      get_panel_page("usermanage")
    end
  end
end
