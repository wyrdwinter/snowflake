const path = require("path");

module.exports = {
    mode: "development",
    entry: {
        main: path.resolve(__dirname, "../jsx/main.jsx"),
        character: path.resolve(__dirname, "../jsx/character.jsx")
    },
    output: {
        filename: "[name].js",
        path: path.resolve(__dirname, "../static/js"),
    },
    module: {
        rules: [
            {
                test: /\.jsx?$/,
                exclude: /node_modules/,
                use: {
                    loader: "babel-loader",
                    options: {
                        cacheDirectory: true,
                        cacheCompression: false,
                        envName: "development",
                        presets: [
                            "@babel/preset-react"
                        ]
                    }
                }
            }
        ]
    },
    resolve: {
        extensions: [".js", ".jsx"]
    }
};
