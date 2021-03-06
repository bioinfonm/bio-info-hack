library("ggplot2")
library("ape")
library("plyr")
library("phyloseq"); packageVersion("phyloseq")
library("vegan")

# Set this to where your working directory is i.e where you biom, mapping file, and 
# rep.set.tree are at
setwd("~/Desktop/bat_microbiota/")

###These need to be the names of your files generated in QIIME 1.8
biom_file = "cave_otu_table.biom"    ###This is your .biom file
map_file = "mapping_8_18_14.csv"      ###This is your mapping file with all the metadata
tree_file = "rep_set_tree.tre"  ### This is the tree built after assinging all taxonomy

# This reads in your newick tree file.
# Comment this out if you don't have a tree and all occuanaces of tree need to be removed
tree <-read_tree(tree_file)

# Reads in a QIIME formatted mapping file
map <- import_qiime_sample_data(map_file)

# Creates the phyloseq object with all data in it
phylo <- import_biom(biom_file,tree_file,parseFunction=parse_taxonomy_greengenes)
# for fungal parseFunction=parse_taxonomy_default
# phylo_fungal <- import_biom(biom_file,parseFunction=parse_taxonomy_default)

# Just for error checking
warnings(phylo)
# I get a lot of warnings all related to some taxonomy assignment issues. 
intersect(phylo)

# This merges everthing into one phyloseq object
phylo <- merge_phyloseq(phylo,map)

# What follows here are a series of checks to verfy that your data was read
# read in correctly
phylo
# You should see something like this
# phyloseq-class experiment-level object
# otu_table()   OTU Table:         [ 5408 taxa and 26 samples ]
# sample_data() Sample Data:       [ 26 samples by 15 sample variables ]
# tax_table()   Taxonomy Table:    [ 5408 taxa by 8 taxonomic ranks ]
# phy_tree()    Phylogenetic Tree: [ 5408 tips and 5406 internal nodes ]

ntaxa(phylo)
sample_names(phylo)
rank_names(phylo)
sample_variables(phylo)
otu_table(phylo)[1:10, 1:5]
tax_table(phylo)[1:10, 1:5]

#Show you all unique taxa
get_taxa_unique(phylo, "Phylum")

# Prune OTUs that are not present in any of the samples
# This should be the only filtering you do at this step! Resisit the urge to filter!!!
phylo <- prune_taxa(taxa_sums(phylo) > 0, phylo)

# UNRARIFEID ALPHA DIVERSITY
# By rarefying you REMOVE OTUs that actaully occur in your samples. Your alpha indices will
# then indicted samples are less rich and diverse then they actualy are.

# LOOK AT THE FIRST LINE THAT STARTS WITH plot_richness
# Change x = "someword" to the metadata category you want to look at
# Change ggtitle to the name of your title

plot_richness(phylo, measures = c("Observed","Chao1", "Shannon"), x = "PLACE") + #geom_boxplot() +
  ggtitle("Alpha Diversity Indices for PROJECTNAME by METADATA") +
  guides(fill = guide_legend(ncol = 3))+
  theme_bw() +
  theme(
    plot.background = element_blank()
    ,panel.grid.major = element_blank()
    ,panel.grid.minor = element_blank()
    ,panel.background = element_blank()
    ,axis.text.x  = element_text(angle=90, vjust=0.5, size=6)
  )

# Transforms to fractional counts so all sample abundances = 1, i.e. normalized
phylo_frac <- transform_sample_counts(phylo, function(OTU) OTU/sum(OTU))

# Transforms to even sampling depth of 1,000,000
phylo_even <- transform_sample_counts(phylo, function(x) 1e+06 * x/sum(x))


phylo_bar <- plot_bar(phylo_even, x="PLACE")
phylo_bar
phylo + geom_bar(aes(color=Phylum, fill=Phylum), stat="identity", position="stack")


# NMDS Ordination
# Simplified NMDS

# Specify the number of dimensions m you want to use (into which you want to scale down the
# distribution of samples in multidimensional space - that's why it's scaling).
# 
# Construct initial configuration of all samples in m dimensions as a starting point of
# iterative process. The result of the whole iteration procedure may depend on this step, 
# so it's somehow crucial - the initial configuration could be generated by random, but better 
# way is to help it a bit, e.g. by using PCoA ordination as a starting position.
# 
# An iterative procedure tries to reshuffle the objects in given number of dimension in such a
# way that the real distances among objects reflects best their compositional dissimilarity. 
# Fit between these two parameters is expressed as so called stress value - the lower stress value
# the better. 
# 
# Algorithm stops when new iteration cannot lower the stress value - the solution has 
# been reached.
# 
# After the algorithm is finished, the final solution is rotated using PCA to ease its interpretation
# (that's why final ordination diagram has ordination axes, even if original algorithm doesn't produce
# any).

# NMDS uses non-linear mapping

# Why Brays-Curtis
# invariant to changes in units
# unaffected by additions/removals of species that are not present in two communities
# unaffected by the addition of a new community
# recognize differences in total abundances when relative abundances are the same

phylo.ord <- ordinate(lb_nmds, "NMDS", "bray")

# stress > 0.05 provides an excellent representation in reduced dimensions, > 0.1 is great,
# >0.2 is good/ok, and stress > 0.3 provides a poor representation

# Shows the stress of the samples. If there is a lage variation around the line then
# your stress is to high. Try k=3. 
stressplot(phylo.ord)

# How well your samples fit. Larger circles are a worse fit. 
gof <- goodness(phylo.ord)
plot(phylo.ord, display = "sites", type = "n")
points(phylo.ord, display = "sites", cex = 2*gof/mean(gof))

# NMDS with type = samples. So a plot of the distances between samples.
# READ THE FIRST LINE THAT STARTS WITH p2 <-
# change color = "someword" to one of your metadata categories

p2 <- plot_ordination(lb_nmds, phylo.ord, type = "samples", color = "REGION",
)+
  #label="X.SampleID" )+
  geom_point(size = 3) + 
  guides(fill = guide_legend(ncol = 3))+
  theme_bw() +
  theme(
    plot.background = element_blank()
    ,panel.grid.major = element_blank()
    ,panel.grid.minor = element_blank()
    ,panel.background = element_blank()
  )
p2

# Density plot version of the sample NMDS
den_nmds_sample = ggplot(p2$data, p2$mapping) + geom_density2d() +
  ggtitle("NMDS Density Plot on Brays Distance by Susceptibility") +
  theme(
    plot.background = element_blank()
    ,panel.grid.major = element_blank()
    ,panel.grid.minor = element_blank()
    ,panel.background = element_blank()
  )
den_nmds_sample

# PCoA Analysis
# PCoA on Unifrac Weighted
# Use the ordinate function to simultaneously perform weightd UniFrac and then perform
# a Principal Coordinate Analysis on that distance matrix (first line)

ordu = ordinate(phylo_frac, "PCoA", "unifrac", weighted = FALSE)

plot_ordination(phylo_frac, ordu, color = "SUBREGION") +
  geom_point(size = 7, alpha = 0.75)+
  ggtitle("MDS/PCoA on Weighted-UniFrac Distance")+
  geom_vline(xintercept=c(0,0), linetype="dotted")+
  geom_hline(xintercept=c(0,0), linetype="dotted")+
  theme_bw() +
  theme(
    plot.background = element_blank()
    ,panel.grid.major = element_blank()
    ,panel.grid.minor = element_blank()
    ,panel.background = element_blank()
  )

# Network Analysis
# Creates a network by OTUs and colors by metadata category
ig <- make_network(para_frac,type ="samples",
                   max.dist = 0.8, distance = "bray", keep.isolates=TRUE)

plot_network(ig, phylo_frac, color="REGION")


