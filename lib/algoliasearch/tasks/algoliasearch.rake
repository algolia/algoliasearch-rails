namespace :algoliasearch do
 
  desc "Reindex all models"
  task :reindex => :environment do
    puts "reindexing all models"
    AlgoliaSearch::Utilities.reindex_all_models
  end
  
  desc "Clear all indexes"
  task :clear_indexes => :environment do
    puts "clearing all indexes"
    AlgoliaSearch::Utilities.clear_all_indexes
  end

end
