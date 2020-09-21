/**
 * Extract a value from the object by path
 * @param {Object} obj Source object
 * @param {string} path Path to value
 * @return {string|number|Array}
 */
const deepValue = (obj, path) => path.split('.').reduce((a, v) => a[v], obj);

/**
 * Parse task property
 * @param {string} property Tasks property
 * @param {Object} resultsScope Array of results of commands finished before
 * @return {Array|string}
 */
const parseProperty = (property, resultsScope) => {

    if (!Array.isArray(property) && property.match(/^\[TASK:/g)) {
        const parts = property.replace(/[\[\]']+/g, '').split(':'); // eslint-disable-line no-useless-escape
        const result = resultsScope[Number(parts[1])];
        return deepValue(result, parts[2]);
    }

    return property;
};

/**
 * Build options for the task command
 * @param {Object} properties Array of properties
 * @param {Object[]} resultsScope Array of results of commands finished before
 * @returns {Object}
 */
module.exports.buildTaskOptions = (properties, resultsScope) => {
    const options = {};
    properties = JSON.parse(JSON.stringify(properties));

    for (const prop in properties) {

        if (typeof properties[prop] === 'string') {
            options[prop] = parseProperty(properties[prop], resultsScope);
        }

        if (Array.isArray(properties[prop])) {
            options[prop] = properties[prop].map(a => parseProperty(a, resultsScope));
        }
    }

    return options;
};

/**
 * Parse grouped command parameters
 * @param {Object} params
 * @returns {Object}
 */
module.exports.parseParamsReplacements = params => {

    if (!params) {
        return {};
    }

    return params.split(',').reduce((a, v) => {
        const param = v.trim().split(':');
        a[`[${param[0]}]`] = param[1];
        return a;
    }, {});
};

/**
 * Replace templated parameters with provided value
 * @param {Object} taskParams
 * @param {Object} replacements
 * @param {Object} resultsScope
 * @returns {Object}
 */
module.exports.applyParamsReplacements = (taskParams, replacements, resultsScope) => {

    if (!replacements || !Object.keys(replacements).length === 0) {
        return taskParams;
    }

    const replace = (param, replacements) => replacements[param]
        ? replacements[param]
        : param;

    const replaceProperty = (property, replacements, resultsScope) => {
        property = replace(property, replacements);
        property = parseProperty(property, resultsScope);
        return property;
    };

    for (const param in taskParams) {

        if (Array.isArray(taskParams[param])) {
            taskParams[param] = taskParams[param].map(p => replaceProperty(p, replacements, resultsScope));
        } else if (typeof param === 'string') {
            taskParams[param] = replaceProperty(taskParams[param], replacements, resultsScope);
        }
    }

    return taskParams;
};
