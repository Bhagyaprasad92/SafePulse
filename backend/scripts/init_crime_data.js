/**
 * Data Initialization Script
 * Processes FIR_Details_Data.csv and populates MongoDB with crime zone data
 * 
 * Usage:
 * node scripts/init_crime_data.js /path/to/FIR_Details_Data.csv
 */

const mongoose = require('mongoose');
const path = require('path');
const { CrimeDataService } = require('../services/crime_data_service');

// MongoDB connection string - update this with your actual connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/safety_app';

async function initializeCrimeData() {
    try {
        console.log('=== Crime Data Initialization ===\n');

        // Get CSV file path from command line argument
        const csvPath = process.argv[2];

        if (!csvPath) {
            console.error('Error: Please provide path to FIR_Details_Data.csv');
            console.log('Usage: node init_crime_data.js <path-to-csv>');
            process.exit(1);
        }

        console.log(`CSV File: ${csvPath}`);
        console.log(`MongoDB URI: ${MONGODB_URI}\n`);

        // Connect to MongoDB
        console.log('Connecting to MongoDB...');
        await mongoose.connect(MONGODB_URI, {
            useNewUrlParser: true,
            useUnifiedTopology: true,
        });
        console.log('✓ Connected to MongoDB\n');

        // Initialize crime data service
        const crimeService = new CrimeDataService();

        // Process FIR data
        console.log('Starting FIR data processing...');
        console.log('This may take several minutes for large datasets...\n');

        const result = await crimeService.processFIRData(csvPath);

        console.log('\n=== Processing Summary ===');
        console.log(`✓ Records processed: ${result.processedCount.toLocaleString()}`);
        console.log(`✓ Records skipped: ${result.skippedCount.toLocaleString()}`);
        console.log(`✓ Crime zones created: ${result.zoneCount.toLocaleString()}`);

        // Verify data in database
        const { CrimeZone } = require('../services/crime_data_service');
        const dbCount = await CrimeZone.countDocuments();
        console.log(`✓ Zones in database: ${dbCount.toLocaleString()}\n`);

        // Get statistics
        const stats = await CrimeZone.aggregate([
            {
                $group: {
                    _id: null,
                    avgRisk: { $avg: '$riskScore' },
                    maxRisk: { $max: '$riskScore' },
                    minRisk: { $min: '$riskScore' },
                    totalCrimes: { $sum: '$crimeData.totalCrimes' },
                    totalHeinous: { $sum: '$crimeData.heinousCrimes' },
                    totalAccidents: { $sum: '$crimeData.accidents' }
                }
            }
        ]);

        if (stats.length > 0) {
            const s = stats[0];
            console.log('=== Crime Statistics ===');
            console.log(`Average risk score: ${s.avgRisk.toFixed(2)}`);
            console.log(`Risk range: ${s.minRisk} - ${s.maxRisk}`);
            console.log(`Total crimes: ${s.totalCrimes.toLocaleString()}`);
            console.log(`Heinous crimes: ${s.totalHeinous.toLocaleString()}`);
            console.log(`Accidents: ${s.totalAccidents.toLocaleString()}\n`);
        }

        // Test query
        console.log('=== Testing Risk Query ===');
        const testLat = 17.385044; // Hyderabad coordinates
        const testLon = 78.486671;
        console.log(`Testing location: ${testLat}, ${testLon}`);

        const testRisk = await crimeService.getRiskAtLocation(testLat, testLon, 1000);
        console.log(`Risk Score: ${testRisk.riskScore}`);
        console.log(`Risk Level: ${testRisk.riskLevel}`);
        console.log(`Nearby Zones: ${testRisk.nearbyZones}\n`);

        console.log('✓ Crime data initialization complete!');
        console.log('✓ Your backend is now ready to use dynamic crime data\n');

    } catch (error) {
        console.error('\n❌ Error during initialization:', error);
        console.error(error.stack);
        process.exit(1);
    } finally {
        // Close MongoDB connection
        await mongoose.connection.close();
        console.log('Database connection closed.');
    }
}

// Run initialization
initializeCrimeData();