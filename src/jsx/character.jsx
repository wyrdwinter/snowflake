/* Copyright (C) 2022 Wyrd (https://github.com/wyrdwinter)

 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.

 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>. */

'use strict'

import React from '../njs/node_modules/react'
import ReactDOM from '../njs/node_modules/react-dom'
import ReactTooltip from '../njs/node_modules/react-tooltip'

const MainTooltip = () => {
  return (
    <ReactTooltip
      html
      place='bottom'
      border
      borderColor='transparent'
      keepThisHere=''
    />
  )
}

ReactDOM.render(React.createElement(MainTooltip), document.querySelector('#main-tooltip'))
