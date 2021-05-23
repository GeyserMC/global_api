const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');
const TerserPlugin = require('terser-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const {CleanWebpackPlugin} = require('clean-webpack-plugin');
const HtmlMinimizerPlugin = require('html-minimizer-webpack-plugin');
const webpack = require('webpack');

module.exports = (env, options) => {
  const devMode = options.mode !== 'production';

  return {
    optimization: {
      // minimize: true,
      minimizer: [
        new TerserPlugin({terserOptions: {sourceMap: devMode}}),
        new CssMinimizerPlugin(),
        new HtmlMinimizerPlugin()
      ]
    },
    entry: {
      'assets/main': './static/assets/main.js'
    },
    output: {
      path: path.resolve(__dirname, '../priv/static')
    },
    devtool: devMode ? 'eval-cheap-module-source-map' : undefined,
    module: {
      rules: [
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader'
          }
        },
        {
          test: /\.[s]?css$/,
          use: [
            MiniCssExtractPlugin.loader,
            'css-loader',
            'postcss-loader',
            'sass-loader',
          ],
        }
      ]
    },
    plugins: [
      new webpack.ProgressPlugin(),
      new CleanWebpackPlugin(),
      new MiniCssExtractPlugin(),
      new CopyWebpackPlugin(
          {
            patterns: [
              {from: './static/', to: './'},
            ]
          }
      )
    ],
    devServer: {
      watchContentBase: true,
      contentBase: './static',
      host: '0.0.0.0',
      open: true
    }
  }
};
