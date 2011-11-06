/**
 * @extends coldmvc.app.helpers.asset
 */
component {

	private string function getAssetURL(required string type, required string name) {

		var assetManager = coldmvc.framework.getBean("assetManager");

		return getBaseURL() & assetManager.getAssetURL(type, name);

	}

}