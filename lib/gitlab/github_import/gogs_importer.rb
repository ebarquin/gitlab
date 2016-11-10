require 'uri'

module Gitlab
  module GogsImport
    class Importer < Gitlab::GithubImport::Importer
      include Gitlab::ShellAdapter

      attr_reader :client, :errors, :project, :repo, :repo_url

      def initialize(project)
        @project  = project
        @repo     = project.import_source
        @repo_url = project.import_url
        @errors   = []
        @labels   = {}

        if credentials
          uri = URI.parse(project.import_url)
          host = "#{uri.scheme}://#{url.host}#{uri.path}".gsub(/[\w-]+\/[\w-]+\.git/, '')
          @client = GithubImport::Client.new(credentials[:user], host: host, api_version: 'v1')
        else
          raise Projects::ImportService::Error, "Unable to find project import data credentials for project ID: #{@project.id}"
        end
      end

      def execute
        import_labels
        import_milestones
        import_issues
        import_pull_requests
        import_comments(:issues)
        import_comments(:pull_requests)
        import_wiki
        # import_releases
        handle_errors

        true
      end
    end
  end
end
