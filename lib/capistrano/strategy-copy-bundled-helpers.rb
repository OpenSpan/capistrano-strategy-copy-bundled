Capistrano::Configuration.instance(true).load do
  namespace :bundle do
    desc 'Creates a back up of local gems to use during rollback'
    task :backup_gems do
      on_rollback { run "cd #{File.join(shared_path, 'bundle')} && tar xf /tmp/#{application}-Gems.tar && rm /tmp/#{application}-Gems.tar" }
      run "cd #{File.join(shared_path, 'bundle')} && tar cf /tmp/#{application}-Gems.tar ."
    end

    task :remove_gem_backup do
      run "rm /tmp/#{application}-Gems.tar"
    end
  end

  before "bundle:install",           "bundle:backup_gems"
  after  "deploy",                   "bundle:remove_gem_backup"
end
