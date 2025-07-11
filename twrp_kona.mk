# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common TWRP stuff.
$(call inherit-product, vendor/twrp/config/common.mk)

# Inherit from kona device
$(call inherit-product, device/moorechip/kona/device.mk)

PRODUCT_DEVICE := kona
PRODUCT_NAME := twrp_kona
PRODUCT_BRAND := moorechip
PRODUCT_MODEL := Retroid Pocket 5
PRODUCT_MANUFACTURER := moorechip

PRODUCT_GMS_CLIENTID_BASE := android-moorechip

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="kona-user 12 SKQ1.211006.001 V14.0.3.0.TKFMIXM release-keys"

BUILD_FINGERPRINT := moorechip/kona/kona:12/SKQ1.211006.001/V14.0.3.0.TKFMIXM:user/release-keys