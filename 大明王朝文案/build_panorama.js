/* 兼容旧命令：先构建唯一内容包，再以同包刷新全景页。 */
require('./build_content_bundle.js');
require('./sync_panorama_from_bundle.js');
