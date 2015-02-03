require 'bundler/deployment'
require 'capistrano'
require 'capistrano/recipes/deploy/strategy/copy'

module Capistrano
  module Deploy
    module Strategy

      class CopyBundled < Copy

        def initialize(config = {})
          super(config)

          #Initialize with default bundler/capistrano tasks (bundle:install)
          configuration.set :rake, lambda { "#{configuration.fetch(:local_bundle_cmd, 'bundle')} exec rake" } unless configuration.exists?(:rake)
          Bundler::Deployment.define_task(configuration, :task, :except => { :no_release => true })
        end

        def deploy!
          logger.info "running :copy_bundled strategy"

          copy_cache ? run_copy_cache_strategy : run_copy_strategy

          create_revision_file

          configuration.trigger('strategy:before:bundle')
          #Bundle all gems
          bundle!
          configuration.trigger('strategy:after:bundle')

          logger.info "compressing repository"
          configuration.trigger('strategy:before:compression')
          compress_repository
          configuration.trigger('strategy:after:compression')


          logger.info "distributing packaged repository"

          configuration.trigger('strategy:before:distribute')
          distribute!
          configuration.trigger('strategy:after:distribute')
        ensure
          rollback_changes
        end

        private

        def bundle!
          bundle_cmd      = configuration.fetch(:local_bundle_cmd, 'bundle')
          bundle_gemfile  = configuration.fetch(:local_bundle_gemfile, 'Gemfile')
          bundle_dir      = configuration.fetch(:local_bundle_dir, 'vendor/bundle')
          bundle_flags    = configuration.fetch(:local_bundle_flags, '--deployment --quiet')
          bundle_without  = [*configuration.fetch(:local_bundle_without, [:development, :test])].compact

          args = ["--gemfile #{File.join(destination, bundle_gemfile)}"]
          args << "--path #{bundle_dir}" unless bundle_dir.to_s.empty?
          args << bundle_flags.to_s unless bundle_flags.to_s.empty?
          args << "--without #{bundle_without.join(" ")}" unless bundle_without.empty?

          Bundler.with_clean_env do
            link_cached_gems!

            logger.info "installing gems to local cache : #{destination}..."
            run_locally "cd #{destination} && #{bundle_cmd} install #{args.join(' ').strip}"

            logger.info "packaging gems for bundler in #{destination}..."
            run_locally "cd #{destination} && #{bundle_cmd} package --all"

            clear_installed_gems!
          end
        end

        def link_cached_gems!
          link_gem_cache  = configuration.fetch(:link_gem_cache, false)
          if link_gem_cache
            logger.info "linking gem cache ($GEM_HOME/cache) to local cache : #{destination}/vendor/bundle/ruby/#{RUBY_VERSION}/cache..."
            run_locally "mkdir -p #{destination}/vendor/bundle/ruby/#{RUBY_VERSION} && rm -rf #{destination}/vendor/bundle/ruby/#{RUBY_VERSION}/cache && ln -s $GEM_HOME/cache #{destination}/vendor/bundle/ruby/#{RUBY_VERSION}/cache"
          end
        end

        def clear_installed_gems!
          logger.info "removing installed gems in #{destination}/vendor/bundle"
          run_locally "rm -rf #{destination}/vendor/bundle"
        end
      end

    end
  end
end
