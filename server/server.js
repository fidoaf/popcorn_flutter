const { createApp } = require('./src/app');

const { config, server } = createApp();

server.listen(config.port, () => {
  console.log(`Server listening on ${config.port}`);
});