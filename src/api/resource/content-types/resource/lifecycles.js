module.exports = {
  async beforeCreate(event) {
    const { data } = event.params;

    if (data.featureImageFile) {
      await populateFeatureImageUrl(data, event);
    }
  },

  async beforeUpdate(event) {
    const { data } = event.params;

    if (data.featureImageFile) {
      await populateFeatureImageUrl(data, event);
    }
  },
};

async function populateFeatureImageUrl(data, event) {
  let imageId = data.featureImageFile;

  // Handle if featureImageFile is an object with id property
  if (typeof imageId === 'object' && imageId !== null) {
    imageId = imageId.id;
  }

  if (imageId) {
    // Fetch the file details from Strapi's upload plugin
    const file = await strapi.plugin('upload').service('upload').findOne(imageId);

    if (file && file.url) {
      // Set the feature_image field with the file URL
      data.feature_image = `https://strapi.macosicons.com${file.url}`;
    }
  }
}
