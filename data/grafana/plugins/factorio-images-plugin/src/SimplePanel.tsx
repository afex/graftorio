import React from 'react';
import { PanelProps } from '@grafana/data';
import { SimpleOptions } from 'types';

interface Props extends PanelProps<SimpleOptions> {}

const REGEX = /\[(?:img|item|entity|recipe|fluid|virtual-signal)=(.*?)]/;
const ICON_REGEX = /icon\[([#@!a-zA-Z\d\-]*)\]/;
const IMAGE_URL = 'https://wiki.factorio.com/images/thumb/';

const fixedSet: { [key: string]: string } = {
  Small_lamp: 'Lamp',
  Rail: 'Straight_rail',
  Stone_wall: 'Wall',
  Logistic_chest_storage: 'Storage_chest',
  Logistic_chest_passive_provider: 'Passive_provider_chest',
  Logistic_chest_active_provider: 'Active_provider_chest',
  Logistic_chest_buffer: 'Buffer_chest',
  Logistic_chest_requester: 'Requester_chest',
  Personal_roboport_equipment: 'Personal_roboport',
  Personal_roboport_mk2_equipment: 'Personal_roboport_MK2',
  Battery_equipment: 'Personal_battery',
  Battery_mk2_equipment: 'Personal_battery_MK2',
  Fusion_reactor_equipment: 'Portable_fusion_reactor',
  Energy_shield_equipment: 'Energy_shield',
  Energy_shield_mk2_equipment: 'Energy_shield_MK2',
  Exoskeleton_equipment: 'Exoskeleton',
  Power_armor_mk2: 'Power_armor_MK2',
  Effectivity_module: 'Efficiency_module',
  Effectivity_module_2: 'Efficiency_module_2',
  Effectivity_module_3: 'Efficiency_module_3',
};

const mapImages = (match: string, second: any): string | string => {
  const extractedItem = second.replace(/item(\.|\/)/g, '');

  let item = extractedItem.charAt(0).toUpperCase() + extractedItem.slice(1);
  if (item.charAt(0) === '#') {
    item = item.replace(/#/g, '');
  } else {
    item = item.replace(/-/g, '_');
  }

  if (fixedSet[item]) {
    item = fixedSet[item];
  }

  let displaySize = 16;
  let imageSize = 16;
  let matchImage = [...item.matchAll(/@([\d]+)X/g)];
  let matchSize = [...item.matchAll(/!([\d]+)X/g)];
  if (matchImage.length > 0) {
    imageSize = matchImage[0][1];
    item = item.replace(/@([\d]+)X/g, '');
  }
  if (matchSize.length > 0) {
    displaySize = matchSize[0][1];
    item = item.replace(/!([\d]+)X/g, '');
  }

  return `<img style="margin: 6px;" width="${displaySize}" src="${IMAGE_URL}${item}.png/${imageSize}px-${item}.png" alt=""/>`;
};

const traversal = (node: any, cb: any): void => {
  if (node.nodeType === 3) {
    cb(node);
  } else if (node instanceof NodeList) {
    node.forEach((element: any) => {
      traversal(element, cb);
    });
  } else {
    node.childNodes.forEach((element: any) => {
      traversal(element, cb);
    });
  }
};

export const SimplePanel: React.FC<Props> = ({ options, data, width, height }) => {
  React.useEffect(() => {
    const interval = setInterval(() => {
      try {
        const cells = document.querySelectorAll('.panel-content');
        traversal(cells, (element: any) => {
          let html = element.parentNode.innerHTML;
          html = html.replace(new RegExp(REGEX, 'g'), mapImages);
          html = html.replace(new RegExp(ICON_REGEX, 'g'), mapImages);
          if (element.parentNode.innerHTML !== html) {
            element.parentNode.innerHTML = html;
          }
        });
        const titles = document.querySelectorAll('.panel-title');
        traversal(titles, (element: any) => {
          let html = element.parentNode.innerHTML;
          html = html.replace(new RegExp(REGEX, 'g'), mapImages);
          html = html.replace(new RegExp(ICON_REGEX, 'g'), mapImages);
          if (element.parentNode.innerHTML !== html) {
            element.parentNode.innerHTML = html;
          }
        });
        const rows = document.querySelectorAll('.dashboard-row__title');
        traversal(rows, (element: any) => {
          let html = element.parentNode.innerHTML;
          html = html.replace(new RegExp(REGEX, 'g'), mapImages);
          html = html.replace(new RegExp(ICON_REGEX, 'g'), mapImages);
          if (element.parentNode.innerHTML !== html) {
            element.parentNode.innerHTML = html;
          }
        });
      } catch (e) {}
    }, 500);
    return () => {
      clearInterval(interval);
    };
  });
  return null;
};
