'use strict';

var VkSdkLoginManager = require('react-native').NativeModules.VkSdkLoginManager;

module.exports = {

    /**
     * Starts authorization process to retrieve unlimited token.
     * If VKapp is available in system, it will opens and requests access from user.
     * Otherwise Mobile Safari will be opened for access request.
     * @returns {Promise}
     */
    authorize: function() {
        return new Promise(function(resolve, reject) {
            VkSdkLoginManager.authorize(function(error, result) {
                if (error) {
                    reject(error);
                } else {
                    resolve(result);
                }
            });
        });
    },

    /**
     * Forces logout using OAuth (with VKAuthorizeController). Removes all cookies for *.vk.com.
     * Has no effect for logout in VK app.
     */
    logout: function() {
        VkSdkLoginManager.logout();
    },

    /**
     * @param {string} methodName
     * @param {Object} [params]
     * @returns {Promise}
     */
    callMethod: function(methodName, params) {
        return new Promise(function(resolve, reject) {
            VkSdkLoginManager.callMethodWithParams(methodName, params || {}, function(error, result) {
                if (error) {
                    reject(error);
                } else {
                    resolve(result);
                }
            });
        });
    },
    
    /**
     * Invokes share dialog. Request for user authorization if required
     * @param {Object} content. Contant to share, supported values for now are "text", "linkURL", "linkTitle", "imageURL"
     * @returns {Promise}
     */
    showShareDialogWithSharingContent: function(content) {
        return new Promise(function(resolve, reject) {
            VkSdkLoginManager.showShareDialogWithSharingContent(content, function(error, result) {
                if (error) {
                    reject(error);
                } else {
                    resolve(result);
                }
            });
        });
    },

    /**
     * Returns friends list. User needs to be authorized
     * @param {string} userFields. Fields to fetch from each friend. If null method return all
     * @returns {Promise}
     */
    getFriendsListWithFields: function(userFields) {
        return new Promise(function(resolve, reject) {
            VkSdkLoginManager.getFriendsListWithFields(userFields, function(error, result) {
                if (error) {
                    reject(error);
                } else {
                    resolve(result);
                }
            });
        });
    },
};
