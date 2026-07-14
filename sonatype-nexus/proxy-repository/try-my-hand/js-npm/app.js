const _ = require('lodash');

console.log("==========================================");
console.log("   JavaScript (Node.js) Nexus Demo App    ");
console.log("==========================================");

const rawData = [1, 2, 2, 3, 4, 4, 5, "Nexus", "Nexus"];
const uniqueData = _.uniq(rawData);

console.log("Original Data :", rawData);
console.log("Filtered Data :", uniqueData);
console.log("==========================================");
