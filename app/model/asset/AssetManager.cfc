/**
 * @accessors true
 * @singleton
 * @setupMethod setup
 */
component {

	/**
	 * @inject coldmvc
	 */
	property coldmvc;

	/**
	 * @inject coldmvc
	 */
	property fileSystem;
	
	/**
	 * @inject coldmvc
	 */
	property pluginManager;

	public any function init() {

		variables.packages = {};
		variables.cache = {};

		variables.types = {
			"script" = "js",
			"style" = "css"
		};

	}

	public struct function getAssets() {

		return variables.cache;

	}

	/**
	 * @events applicationStart
	 */
	public void function loadAssets() {

		deleteAssets();
		findAssets("js");
		findAssets("images");
		findAssets("css");

	}

	private void function deleteAssets() {

		lock name="plugins.assets.app.model.AssetManager" type="exclusive" timeout="5" throwontimeout="true" {
			deleteDirectory("js");
			deleteDirectory("css");
			deleteDirectory("images");
		}

	}

	private void function deleteDirectory(required string directory) {

		arguments.directory = expandPath("/public/#arguments.directory#/plugins/");

		if (fileSystem.directoryExists(arguments.directory)) {
			directoryDelete(arguments.directory, true);
		}

	}

	private void function findAssets(required string directory) {

		variables.cache[arguments.directory] = {};

		var plugins = pluginManager.getPlugins();
		var i = "";
		var j = "";
		var paths = [];

		arrayAppend(paths, {
			source = "/public/" & arguments.directory & "/",
			url = "/" & arguments.directory & "/",
			destination = ""
		});

		for (i = 1; i <= arrayLen(plugins); i++) {

			arrayAppend(paths, {
				source = plugins[i].mapping & "/public/" & arguments.directory & "/",
				url = "/" & arguments.directory & "/plugins/" & plugins[i].name & "/",
				destination = "/public/" & arguments.directory & "/plugins/" & plugins[i].name & "/"
			});

		}

		for (i = 1; i <= arrayLen(paths); i++) {

			var expandedDirectory = replace(expandPath(paths[i].source), "\", "/", "all");

			if (fileSystem.directoryExists(expandedDirectory)) {

				var files = directoryList(expandedDirectory, true, "path");

				for (j = 1; j <= arrayLen(files); j++) {

					var filePath = replace(files[j], "\", "/", "all");
					var name = replace(filePath, expandedDirectory, "");

					if (!structKeyExists(variables.cache[arguments.directory], name)) {

						var asset = {
							name = name,
							source = paths[i].source & name,
							destination = paths[i].destination & name,
							url = paths[i].url & name,
							generated = false
						};

						if (paths[i].destination == "") {
							asset.generated = true;
						}

						variables.cache[arguments.directory][asset.name] = asset;

					}

				}

			}

		}

	}

	public string function getAssetURL(required string type, required string name) {

		if (structKeyExists(variables.cache, arguments.type) && structKeyExists(variables.cache[arguments.type], arguments.name)) {

			var asset = variables.cache[arguments.type][arguments.name];

			if (!asset.generated) {

				var source = expandPath(asset.source);
				var destination = expandPath(asset.destination);
				var directory = getDirectoryFromPath(destination);

				if (!fileSystem.directoryExists(directory)) {
					directoryCreate(directory);
				}

				fileCopy(source, destination);
				asset.generated = true;
			}

			return asset.url;

		}

		return "/" & arguments.type & "/" & arguments.name;

	}

	public void function setup() {

		var plugins = pluginManager.getPlugins();
		var path = "/config/assets.xml";
		var i = "";

		loadXML(path);

		for (i = 1; i <= arrayLen(plugins); i++) {
			loadXML(plugins[i].mapping & path);
		}

		loadXML("/coldmvc" & path);


	}

	public void function loadXML(required string filePath) {

		if (!fileSystem.fileExists(arguments.filePath)) {
			arguments.filePath = expandPath(arguments.filePath);
		}

		if (fileSystem.fileExists(arguments.filePath)) {

			var xml = xmlParse(fileRead(arguments.filePath));
			var i = "";
			for (i = 1; i <= arrayLen(xml.packages.xmlChildren); i++) {

				var packageXML = xml.packages.xmlChildren[i];
				var package = getPackage(coldmvc.xml.get(packageXML, "name", "application"));
				var j = "";

				for (j = 1; j <= arrayLen(packageXML.xmlChildren); j++) {

					var assetXML = packageXML.xmlChildren[j];
					var type = types[assetXML.xmlName];
					var asset = {};
					asset.name = assetXML.xmlAttributes.name;
					asset.path = coldmvc.xml.get(assetXML, "path", "/public/#type#/#asset.name#");
					asset.url = coldmvc.xml.get(assetXML, "url");

					if (!structKeyExists(package[type].struct, asset.name)) {
						package[type].struct[asset.name] = asset;
						arrayAppend(package[type].array, asset);

					}

				}

			}

		}

	}

	public struct function getPackage(required string name) {

		if (!structKeyExists(variables.packages, arguments.name)) {

			variables.packages[arguments.name] = {
				css = {
					struct = {},
					array = [],
					path = "",
					html = []
				},
				js = {
					struct = {},
					array = [],
					path = "",
					html = []
				},
				generated = false,
				html = []
			};

		}

		return variables.packages[arguments.name];

	}

	public string function renderPackage(required string name) {

		var package = getPackage(arguments.name);

		if (!package.generated) {

			package.html = [];

			if (arrayLen(package.css.array) > 0) {

				generatePackage(package, arguments.name, "css");
				package.html.addAll(package.css.html);
				package.css.url = coldmvc.asset.linkToCSS("packages/#arguments.name#.css");

				arrayAppend(package.html, '<link rel="stylesheet" href="#package.css.url#?v=#package.css.hash#" type="text/css" media="all" />');

			}

			if (arrayLen(package.js.array) > 0) {

				generatePackage(package, arguments.name, "js");
				package.html.addAll(package.js.html);
				package.js.url = coldmvc.asset.linkToJS("packages/#arguments.name#.js");

				arrayAppend(package.html, '<script type="text/javascript" src="#package.js.url#?v=#package.js.hash#"></script>');

			}

			package.html = arrayToList(package.html, chr(10));

			package.generated = true;

		}

		return package.html;

	}

	private void function generatePackage(required struct package, required string name, required string type) {

		var assets = arguments.package[arguments.type].array;
		var content = [];
		var i = "";

		for (i = 1; i <= arrayLen(assets); i++) {

			var asset = assets[i];

			if (asset.url != "") {

				if (arguments.type == "css") {
					arrayAppend(arguments.package[arguments.type].html, '<link rel="stylesheet" href="#asset.url#" type="text/css" media="all" />');
				} else {
					arrayAppend(arguments.package[arguments.type].html, '<script type="text/javascript" src="#asset.url#"></script>');
				}

			} else {

				arrayAppend(content, "/* #asset.name#: #asset.path# */" & chr(10) & fileRead(expandPath(asset.path)));

			}

		}

		content = arrayToList(content, chr(10) & chr(10));

		arguments.package[arguments.type].hash = lcase(hash(content));

		var directory = expandPath("/public/#arguments.type#/packages/");

		if (!fileSystem.directoryExists(directory)) {
			directoryCreate(directory);
		}

		fileWrite(directory & "#arguments.name#.#arguments.type#", content);

	}

}