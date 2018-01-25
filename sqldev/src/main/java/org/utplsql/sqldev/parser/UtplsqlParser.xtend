/* Copyright 2018 Philipp Salvisberg <philipp.salvisberg@trivadis.com>
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.utplsql.sqldev.parser

import java.util.ArrayList
import java.util.regex.Pattern
import javax.swing.text.JTextComponent
import org.utplsql.sqldev.model.parser.PlsqlObject
import org.utplsql.sqldev.model.parser.Unit

class UtplsqlParser {
	private String plsql
	private String plsqlWithoutComments
	private ArrayList<PlsqlObject> objects = new ArrayList<PlsqlObject>
	private ArrayList<Unit> units = new ArrayList<Unit>
	
	new(String plsql) {
		this.plsql = plsql
		setPlsqlWithoutComments
		populateObjects
		populateUnits
	}
	
	/**
	 * replace multi-line and single-line PL/SQL comments with space
	 * to simplify and improve performance of subsequent regex expressions 
	 */
	private def setPlsqlWithoutComments() {
		val sb = new StringBuffer
		val p = Pattern.compile("(/\\*(.|[\\r\\n])*?\\*/)|(--.*\\r?\\n)")
		val m = p.matcher(plsql)
		var pos = 0
		while (m.find) {
			if (pos < m.start) {
				sb.append(plsql.substring(pos, m.start))
			}
			for (var i=m.start; i<m.end; i++) {
				val c = plsql.substring(i, i+1)
				if (c == "\n" || c == "\r") {
					sb.append(c)
				} else {
					sb.append(" ")
				}
			}
			pos = m.end
		}
		if (plsql.length > pos) {
			sb.append(plsql.substring(pos, plsql.length))
		}
		plsqlWithoutComments=sb.toString
	}
	
	private def populateObjects() {
		val p = Pattern.compile("(?i)(\\s*)(create(\\s+or\\s+replace)?\\s+(package|type)\\s+(body\\s+)?)(.+?)(\\s+)")
		val m = p.matcher(plsqlWithoutComments)
		while (m.find) {
			val o = new PlsqlObject
			o.name = m.group(6)
			o.position = m.start
			objects.add(o)
		}
	}
	private def populateUnits() {
		val p = Pattern.compile("(?i)(\\s*)(function|procedure)(\\s+)(.+?)(\\s+)")
		val m = p.matcher(plsqlWithoutComments)
		while (m.find) {
			val u = new Unit
			u.name = m.group(4)
			u.position = m.start
			units.add(u)
		}
	}
	
	private def getObjectNameAt(int position) {
		var name = ""
		for (o : objects) {
			if (o.position <= position) {
				name = o.name
			}
		}
		return name
	}
	
	private def getUnitNameAt(int position) {
		var name = ""
		for (u : units) {
			if (u.position <= position) {
				name = u.name
			}
		}
		return name
	}
	
	private def fixName(String name) {
		return name.replace("\"", "").replace(";", "")
	}
	
	def getObjects() {
		return objects
	}
	
	def getUnits() {
		return units
	}

	/**
	 * gets the utPLSQL path based on the current editor position
	 * 
	 * @param position the absolute position as used in {@link JTextComponent#getCaretPosition()}
	 * @return the utPLSQL path
	 */
	def getPathAt(int position) {
		var objectName = getObjectNameAt(position)
		if (!objectName.empty) {
			var unitName = getUnitNameAt(position)
			if (unitName.empty) {
				return objectName.fixName
			} else {
				return '''«objectName.fixName».«unitName.fixName»'''
			}
		}
		return ""
	}
	
	/**
	 * gets the utPLSQL path based on the current editor position
	 *
	 * @param line the line as used in SQL Developer, starting with 1
	 * @param column the column as used in SQL Developer, starting with 1
	 * @return the utPLSQL path
	 */
	def getPathAt(int line, int column) {
		var lines=0
		for (var i=0; i<plsql.length; i++) {
			if (plsql.substring(i,i+1) == "\n") {
				lines++
				if (lines == line - 1) {
					return getPathAt(i + column)
				}
			}
		}
		throw new RuntimeException('''Line «line» not found.''')
	}

}