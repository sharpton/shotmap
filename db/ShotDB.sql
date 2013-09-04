-- MySQL dump 10.13  Distrib 5.5.29, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: SFams_MH
-- ------------------------------------------------------
-- Server version	5.5.29-0ubuntu0.12.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `classification_parameters`
--

DROP TABLE IF EXISTS `classification_parameters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `classification_parameters` (
  `classification_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `evalue_threshold` double DEFAULT NULL,
  `coverage_threshold` float DEFAULT NULL,
  `score_threshold` float DEFAULT NULL,
  `method` varchar(30) DEFAULT NULL,
  `reference_database_name` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`classification_id`),
  KEY `evalue_threshold` (`evalue_threshold`),
  KEY `coverage_threshold` (`coverage_threshold`),
  KEY `score_threshold` (`score_threshold`),
  KEY `method` (`method`),
  KEY `reference_database_name` (`reference_database_name`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `metareads`
--

DROP TABLE IF EXISTS `metareads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `metareads` (
  `read_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `sample_id` int(11) unsigned NOT NULL,
  `read_alt_id` varchar(256) NOT NULL,
  `seq` text DEFAULT NULL,
  PRIMARY KEY (`read_id`),
  UNIQUE KEY `sample_id_read_alt_id` (`sample_id`,`read_alt_id`),
  KEY `sampleid` (`sample_id`)
  /*,
  CONSTRAINT `metareads_ibfk_1` FOREIGN KEY (`sample_id`) REFERENCES `samples` (`sample_id`) ON DELETE CASCADE ON UPDATE CASCADE*/
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `orfs`
--

DROP TABLE IF EXISTS `orfs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `orfs` (
  `orf_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `sample_id` int(11) unsigned NOT NULL,
  /*`read_id` int(11) unsigned DEFAULT NULL, */
  `read_alt_id` varchar(256) DEFAULT NULL,
  `orf_alt_id` varchar(256) NOT NULL,
  `start` int(5) DEFAULT NULL,
  `stop` int(5) DEFAULT NULL,
  `frame` enum('0','1','2') DEFAULT NULL,
  `strand` enum('-','+') DEFAULT NULL,
  `seq` text DEFAULT NULL,
  PRIMARY KEY (`orf_id`),
  UNIQUE KEY `sample_id_orf_alt_id` (`sample_id`,`orf_alt_id`),
  UNIQUE KEY `sample_id_read_alt_id` (`sample_id`,`read_alt_id`),
  /*KEY `read_id` (`read_id`), */
  KEY `read_alt_id` (`read_alt_id`),
  KEY `sample_id` (`sample_id`) 
  /*,
  CONSTRAINT `orfs_ibfk_1` FOREIGN KEY (`read_id`) REFERENCES `metareads` (`read_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `orfs_ibfk_2` FOREIGN KEY (`sample_id`) REFERENCES `samples` (`sample_id`) ON DELETE CASCADE ON UPDATE CASCADE*/
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `project`
--

DROP TABLE IF EXISTS `project`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `project` (
  `project_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(64) DEFAULT NULL,
  `description` text,
  PRIMARY KEY (`project_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;


--
-- Table structure for table `samples`
--

DROP TABLE IF EXISTS `samples`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `samples` (
  `sample_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `project_id` int(11) unsigned DEFAULT NULL,
  `sample_alt_id` varchar(256) NOT NULL,
  `name` varchar(128) DEFAULT NULL,
  `metadata` text, /*comma-delimited, key=value pairings for sample, assembled from sample_metadata.tab*/
  PRIMARY KEY (`sample_id`),
  UNIQUE KEY `sample_alt_id` (`sample_alt_id`),
  UNIQUE KEY `project_id_sample_alt_id` (`project_id`,`sample_alt_id`),
  KEY `project_id` (`project_id`),
  CONSTRAINT `samples_ibfk_1` FOREIGN KEY (`project_id`) REFERENCES `project` (`project_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;


--
-- Table structure for table `searchresults`
--

DROP TABLE IF EXISTS `searchresults`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `searchresults` (
  `searchresult_id` int(11) NOT NULL AUTO_INCREMENT,
  `orf_alt_id` varchar(256) NOT NULL, /*FASTER FOR WORKFLOW IF WE STORE ALT_ID*/
  `read_alt_id` varchar(256) NOT NULL, /*FASTER FOR WORKFLOW IF WE STORE ALT_ID*/
  `sample_id` int(11) unsigned NOT NULL, /*NOTE NO FOREIGN KEY CHECK!*/
  `target_id` varchar(256) NOT NULL, 
  `famid` varchar(256) NOT NULL, /*NOTE NO FOREIGN KEY CHECK!*/
  `classification_id` int(10) unsigned NOT NULL, /*NOTE NO FOREIGN KEY CHECK!*/
  `score` float DEFAULT NULL,
  `evalue` double DEFAULT NULL,
  `orf_coverage` float DEFAULT NULL,
  `aln_length` float DEFAULT NULL,
  PRIMARY KEY (`searchresult_id`),
  UNIQUE KEY `orf_fam_sample_class_id` (`orf_alt_id`,`target_id`,`famid`,`sample_id`,`classification_id`), /*THIS IS FOR SAFETY*/ 
  KEY `orfalt_sample_id` (`orf_alt_id`,`sample_id`),
  KEY `famid` (`famid`),
  KEY `readalt_sample_id` (`read_alt_id`,`sample_id`),
  KEY `sampleid` (`sample_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `classifications`
--

DROP TABLE IF EXISTS `classifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `classifications` (
  `result_id` int(11) NOT NULL AUTO_INCREMENT,
  `orf_alt_id` varchar(256) NOT NULL, /*FASTER FOR WORKFLOW IF WE STORE ALT_ID*/
  `read_alt_id` varchar(256) NOT NULL, /*FASTER FOR WORKFLOW IF WE STORE ALT_ID*/
  `sample_id` int(11) unsigned NOT NULL, /*NOTE NO FOREIGN KEY CHECK!*/
  `target_id` varchar(256) NOT NULL, 
  `famid` varchar(256) NOT NULL, /*NOTE NO FOREIGN KEY CHECK!*/
  `classification_id` int(10) unsigned NOT NULL, /*NOTE NO FOREIGN KEY CHECK!*/
  `aln_length` float DEFAULT NULL,
  `score` float DEFAULT NULL,
  PRIMARY KEY (`result_id`),
  UNIQUE KEY `orf_fam_sample_class_id` (`orf_alt_id`,`famid`,`sample_id`,`classification_id`), /*THIS IS FOR SAFETY*/ 
  KEY `orfalt_sample_id` (`orf_alt_id`,`sample_id`),
  KEY `famid` (`famid`),
  KEY `readalt_sample_id` (`read_alt_id`,`sample_id`),
  KEY `sampleid` (`sample_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `abundance_parameters`
--

DROP TABLE IF EXISTS `abundance_parameters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `abundance_parameters` (
  `abundance_parameter_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `abundance_type` varchar(256) DEFAULT NULL, /*binary, alignment length corrected*/
  `normalization_type` varchar(256) DEFAULT NULL, /*e.g., target length, family length, none*/
  `rarefaction_depth` int(10) unsigned DEFAULT NULL,
  `rarefaction_type`  varchar(256) DEFAULT NULL, /*pre-rarefication or post-rarefication*/
  PRIMARY KEY (`abundance_parameter_id`),
  KEY `abundance_type` (`abundance_type`),
  KEY `normalization_type` (`normalization_type`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table abundances`
--

DROP TABLE IF EXISTS `abundances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `abundances` (
  `abundance_id` int(11) NOT NULL AUTO_INCREMENT,
  `sample_id`  int(11) unsigned NOT NULL, /*NOTE NO FOREIGN KEY CHECK!*/
  `famid` varchar(256) NOT NULL, /*NOTE NO FOREIGN KEY CHECK!*/
  `abundance` float NOT NULL, /*FASTER FOR WORKFLOW IF WE STORE ALT_ID*/
  `relative_abundance` float NOT NULL, /*NOTE NO FOREIGN KEY CHECK!*/
  `abundance_parameter_id` int(10) unsigned NOT NULL,
  `classification_id` int(11) unsigned DEFAULT NULL,  
  PRIMARY KEY (`abundance_id`),
  UNIQUE KEY `fam_sample_type_id` (`sample_id`,`famid`,`abundance_parameter_id`), /*THIS IS FOR SAFETY*/ 
  KEY `fam_sample_id` (`famid`,`sample_id`),
  KEY `type_sample_id` (`abundance_parameter_id`,`sample_id`),
  KEY `famid` (`famid`),
  KEY `sampleid` (`sample_id`),
  KEY `classification_id` (`classification_id`),
  KEY `abundanceparameter` (`abundance_parameter_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `searchdatabases`
--

DROP TABLE IF EXISTS `searchdatabases`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `searchdatabases` (
  `searchdb_id` int(11) NOT NULL AUTO_INCREMENT, 
  `db_type` varchar(256) NOT NULL,
  `db_name` varchar(256) NOT NULL,
  PRIMARY KEY (`searchdb_id`),
  UNIQUE KEY `name_type` (`db_name`,`db_type`), /*THIS IS FOR SAFETY*/
  KEY `db_type` (`db_type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `familymembers`
--

DROP TABLE IF EXISTS `familymembers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `familymembers` (
  `member_id` int(11) NOT NULL AUTO_INCREMENT, /*INTERNAL ID*/
  `famid` varchar(256) NOT NULL, /*LOADED FROM FLAT FILES*/
  `target_id` varchar(256) NOT NULL, /*LOADED FROM FLAT FILES*, IN SOME DBS, WE HAVE MULTIPLE TARGET_ID, FAMID MAPPINGS (e.g, KEGG)*/
  `target_length` int(11) DEFAULT NULL, /*HOW LONG IS THE TARGET SEQUENCE, NULL FOR HMMS*/
  `searchdb_id` int(11) NOT NULL,
  PRIMARY KEY (`member_id`),
  UNIQUE KEY `member_id` (`member_id`), /*THIS IS FOR SAFETY*/
  KEY `famid` (`famid`),
  KEY `target_id` (`target_id`),
  KEY `searchdb_id` (`searchdb_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `families`
--

DROP TABLE IF EXISTS `families`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `families` (
  `internal_famid` int(11) NOT NULL AUTO_INCREMENT,
  `famid` varchar(256) NOT NULL, /*famid, searchdb_id must be unique!*/
  `family_length` int(11) DEFAULT NULL, /*EITHER LENGTH OF HMM OR MEAN FAMILY MEMBER LENGTH*/
  `family_size` int(11) DEFAULT NULL, /*HOW MANY MEMBERS ARE IN THE FAMILY? CAN BE NULL IN CASE OF HMMS*/
  `searchdb_id` int(11) NOT NULL,
  PRIMARY KEY (`internal_famid`),
  UNIQUE KEY `famid_searchdb_id` (`famid`,`searchdb_id`), /*THIS IS FOR SAFETY*/
  KEY `famid` (`famid`),
  KEY `searchdb_id` (`searchdb_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `annotations`
--

DROP TABLE IF EXISTS `annotations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `annotations` (
  `annotation_id` int(11) NOT NULL AUTO_INCREMENT,
  `famid` varchar(256) NOT NULL, /*does not have to be unique, may map to multiple annotations*/
  `annotation_string` varchar(256) DEFAULT NULL, /*THIS IS AN ANNOTATION STRING, LIKE "GLYCOSIDE HYDROLASE"*/
  `annotation_type_id` varchar(256) DEFAULT NULL, /*THIS IS AN ID THAT MAPS TO ANNOTATION STRING, LIKE IPR013781*/  
  `annotation_type` varchar(256) DEFAULT NULL, /*ANNOTATION METHOD, LIKE INTERPRO*/
  `searchdb_id` int(11) NOT NULL,
  PRIMARY KEY (`annotation_id`),
  UNIQUE KEY `famid_searchdb_annotation_type_id` (`famid`,`searchdb_id`,`annotation_type_id`), /*THIS IS FOR SAFETY*/
  KEY `famid` (`famid`),
  KEY `annotation_type_id` (`annotation_type_id`),
  KEY `annotation_type` (`annotation_type`),
  KEY `searchdb_id` (`searchdb_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;


/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-02-28 14:33:29
