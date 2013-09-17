namespace :algoliasearch do
 
  desc "Reindex all models"
  task :reindex => :environment do
    puts "reindexing all models"
    load_models
    AlgoliaSearch::Utilities.reindex_all_models
  end
  
  desc "Clear all indexes"
  task :clear_indexes => :environment do
    puts "clearing all indexes"
    load_models
    AlgoliaSearch::Utilities.clear_all_indexes
  end
  
  def load_models
    app_root = Rails.root
    dirs = ["#{app_root}/app/models/"] + Dir.glob("#{app_root}/vendor/plugins/*/app/models/")
    
    dirs.each do |base|
      Dir["#{base}**/*.rb"].each do |file|
        model_name = file.gsub(/^#{base}([\w_\/\\]+)\.rb/, '\1')
        next if model_name.nil?
        model_name.camelize.constantize
      end
    end
  end
end
