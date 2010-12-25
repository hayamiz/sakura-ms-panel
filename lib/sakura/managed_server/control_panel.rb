
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

    # default settings
    #  :comment => "",
    #  :use_mail => true,
    #  :use_ftp => false,
    #  :use_file_sharing => false,
    #  :mail_quota => 200, # in MB
    #  :virus_check => false,
    #  :spam_filter => false
    def user_add(username, password,
                 config = Hash.new)
      default_config = {
        :add_user => true,
        :password => password,
        :comment => "",
        :use_mail => true,
        :use_ftp => false,
        :use_file_sharing => false,
        :mail_quota => 200, # in MB
        :virus_check => false,
        :spam_filter => false
      }

      user_setting(username,
                   default_config.merge(config))
    end

    # settings with default values
    #  :password
    #  :comment => "",
    #  :use_mail => true,
    #  :use_ftp => false,
    #  :use_file_sharing => false,
    #  :mail_quota => 200, # in MB
    #  :virus_check => false,
    #  :spam_filter => false
    def user_setting(username,
                     settings = Hash.new)
      if settings[:add_user]
        page = page_usermanage
      else
        page = page_usermanage("Username" => username)
      end
      form = page.form_with(:name => "userform")

      if settings[:add_user]
        form.field_with(:name => "Username").value = username
      end

      if ! settings[:comment].nil?
        form.field_with(:name => "Comment").value = settings[:comment]
      end

      if ! settings[:password].nil?
        form.field_with(:name => "Password1").value = settings[:password]
        form.field_with(:name => "Password2").value = settings[:password]
      end

      if ! settings[:use_mail].nil?
        if settings[:use_mail]
          form.checkbox_with(:name => "Mail").check
        else
          form.checkbox_with(:name => "Mail").uncheck
        end
      end

      if ! settings[:use_ftp].nil?
        if settings[:use_ftp]
          form.checkbox_with(:name => "Web").check
        else
          form.checkbox_with(:name => "Web").uncheck
        end
      end

      if ! settings[:use_file_sharing].nil?
        if settings[:use_file_sharing]
          form.checkbox_with(:name => "WebDAV").check
        else
          form.checkbox_with(:name => "WebDAV").uncheck
        end
      end

      if settings[:use_mail] == true && settings[:mail_quota].nil?
        settings[:mail_quota] = form.field_with(:name => "MailQuota").value
        if settings[:mail_quota].nil? || settings[:mail_quota].empty?
          settings[:mail_quota] = "200"
        end
      end

      if ! settings[:mail_quota].nil?
        if ! settings[:mail_quota].empty?
          form.field_with(:name => "MailQuota").value = settings[:mail_quota]
        end
      end

      if ! settings[:virus_check].nil?
        if settings[:virus_check]
          form.radiobuttons_with(:name => "VirusScan")[1].check
        else
          form.radiobuttons_with(:name => "VirusScan")[0].check
        end
      end

      if ! settings[:spam_filter].nil?
        if settings[:spam_filter]
          form.radiobuttons_with(:name => "SpamFilter")[1].check
        else
          form.radiobuttons_with(:name => "SpamFilter")[0].check
        end
      end

      result_page = @agent.submit(form, form.button_with(:name => "Submit_usermanage"))

      if result_page.uri == URL_PANEL_TOP + "user"
        username
      else
        false
        return result_page
      end
    end

    # default settings
    #  :forward_only => false
    #  :forward_addrs => ""
    #  :virus_check => false
    #  :spam_filter => false
    def user_mail_setting(username,
                          settings = Hash.new)
      page = page_usermail(username)
      form = page.form_with(:name => "usermail")

      if ! settings[:forward_only].nil?
        if settings[:forward_only] == true
          form.radiobuttons_with(:name => "MailBox")[0].check
        else
          form.radiobuttons_with(:name => "MailBox")[1].check
        end
      end

      if ! settings[:forward_addrs].nil?
        if ! settings[:forward_addrs].empty?
          form.field_with(:name => "Transfer").value = settings[:forward_addrs]
        end
      end

      if ! settings[:virus_check].nil?
        if settings[:virus_check] == true
          form.radiobuttons_with(:name => "VirusScan")[1].check
        else
          form.radiobuttons_with(:name => "VirusScan")[0].check
        end
      end

      if ! settings[:spam_filter].nil?
        if settings[:spam_filter] == true
          form.radiobuttons_with(:name => "SpamFilter")[1].check
        else
          form.radiobuttons_with(:name => "SpamFilter")[0].check
        end
      end

      result_page = @agent.submit(form, form.button_with(:name => "Submit_usermail"))

      if result_page.uri == URL_PANEL_TOP + "usermail"
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

    def get_panel_page(rel_path, param)
      if ! logged_in?
        login
      end

      uri = URL_PANEL_TOP + rel_path
      uri.query = URI.encode_www_form(param)

      get(uri)
    end

    def page_user
      get_panel_page("user")
    end
    def page_usermanage(param = Hash.new)
      get_panel_page("usermanage", param)
    end
    def page_usermail(username)
      get_panel_page("usermail", "Username" => username)
    end
  end
end
